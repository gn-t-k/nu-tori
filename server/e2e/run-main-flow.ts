import { isDeepStrictEqual } from "node:util";
import { z } from "zod";
import { mealTextBody } from "./meal-text-body";
import { addDays } from "../src/domain/add-days";
import { computeCalendarDayInTimeZone } from "../src/domain/compute-calendar-day-in-time-zone";
import { computeStartOfWeek } from "../src/domain/compute-start-of-week";
import { millisecondsPerDay } from "../src/domain/milliseconds-per-day";
import { generateRecordId } from "../src/domain/record-id";
import { e2eRequestHeaders } from "../src/http/e2e-access";
import { goalDecisionSchema } from "../src/http/goal-setup-routes/goal-decision-schema";
import { goalProposalsSchema } from "../src/http/goal-setup-routes/goal-proposals-schema";
import { goalSetupPreviewSchema } from "../src/http/goal-setup-routes/goal-setup-preview-schema";
import { replyStreamEventSchema } from "../src/http/reply-stream-routes/reply-stream-event-schema";

// 送る文章は作り話にする（公開リポジトリ）
const conversationTextBody = "今日はよく歩いたので、少し脚が疲れた";

// 開発用の環境へデプロイした Worker の本物の API を叩き、サインインから目標を決めて1日の目安が届くこと、週の見直し、写真と文章の食事の推定、会話の文章への返事、アカウントの削除までを通す。
// そのあと、無料体験の終わったアカウントで、写真の食事の推定がサブスクリプションを待っているになることを確かめる。
// 失敗したら、どの段で何が起きたかを書いて投げる。サインインしたあとは、失敗してもアカウントを消してから投げる
export const runMainFlow = async (options: MainFlowOptions): Promise<void> => {
  const session = await signIn(options);
  options.log("サインインした");
  await withAccountDeletion(options, session, () => runFreeTrialFlow(options, session));
  options.log("アカウントを削除した");
  await requireSessionRevoked(options, session);

  // 課金を入れた日（開発用の BILLING_STARTED_ON）が30日より前なら、使い始めた日を30日より前にすると無料体験が終わる
  const expiredSession = await signIn(
    options,
    new Date(Date.now() - expiredAccountAgeDays * millisecondsPerDay),
  );
  options.log(`${expiredAccountAgeDays}日前に使い始めたことにしてサインインした`);
  await withAccountDeletion(options, expiredSession, () =>
    runExpiredFreeTrialFlow(options, expiredSession),
  );
  options.log("無料体験の終わったアカウントを削除した");
};

const expiredAccountAgeDays = 60;

const runFreeTrialFlow = async (options: MainFlowOptions, session: Session): Promise<void> => {
  const freeTrialLastDay = await readFreeTrialLastDay(options, session);
  if (freeTrialLastDay === undefined || freeTrialLastDay < computeTodayOfStartedOn()) {
    throw new Error(
      `作ったばかりのアカウントが無料体験中でない（最後の日: ${freeTrialLastDay ?? "なし"}）`,
    );
  }
  options.log("無料体験中のアカウントだった");
  // 新しいアカウントは前の週を持たないので、体重を量って目標を決めたのを 7 日前にする。
  // 開始の日が前の週に入り、今週の月曜の週がまだ見直していない週になる
  const goalDecidedAt = new Date(Date.now() - 7 * millisecondsPerDay);
  await recordWeight(options, session, new Date(goalDecidedAt.getTime() - 60_000));
  options.log("7日前の体重を記録した");
  const goalId = await decideGoal(options, session, goalDecidedAt);
  await requirePulledWeeklyReview(options, session, goalId);
  const mealId = await sendPhotographedMeal(options, session);
  options.log("写真の食事を送った");
  const { dishIds, ingredientCount } = await waitForEstimation(options, session, mealId);
  options.log(`推定できた（料理 ${dishIds.length}、材料 ${ingredientCount}）`);
  await renameEstimatedDish(options, session, dishIds[0]);
  options.log("推定でできた料理の名前を直した");
  const mealTextId = await sendText(options, session, mealTextBody);
  options.log("食事の文章を送った");
  const writtenMeal = await waitForWrittenMealEstimation(options, session, mealTextId);
  options.log(
    `文章の食事が推定できた（料理 ${writtenMeal.dishIds.length}、材料 ${writtenMeal.ingredientCount}）`,
  );
  const conversationTextId = await sendText(options, session, conversationTextBody);
  options.log("会話の文章を送った");
  const streamedReply = await watchReply(options, session, conversationTextId);
  options.log(`見守る要求で返事が届いた（流れた分 ${streamedReply.textDeltaCount}）`);
  await requirePulledReply(options, session, conversationTextId, streamedReply);
  options.log("取りに行くで返事が届いた");
};

// 無料体験の終わったアカウントで撮った食事は、推定を始めず、推定の状態がサブスクリプションを待っているになる
const runExpiredFreeTrialFlow = async (
  options: MainFlowOptions,
  session: Session,
): Promise<void> => {
  const freeTrialLastDay = await readFreeTrialLastDay(options, session);
  if (freeTrialLastDay === undefined || freeTrialLastDay >= computeTodayOfStartedOn()) {
    throw new Error(
      `${expiredAccountAgeDays}日前に使い始めたことにしても、無料体験が終わっていない（開発用の BILLING_STARTED_ON を30日より前の日にする。最後の日: ${freeTrialLastDay ?? "なし"}）`,
    );
  }
  options.log("無料体験の終わったアカウントだった");
  const mealId = await sendPhotographedMeal(options, session);
  options.log("無料体験の終わったアカウントで写真の食事を送った");
  await waitForChanges(options, session, {
    goal: "サブスクリプションを待っている",
    timeoutMs: options.estimationTimeoutMs,
    inspect: (changes): Inspection<undefined> => {
      const status = findEstimationStatus(changes, mealId) ?? "未取得";
      if (status === "awaiting_subscription") {
        return { done: undefined };
      }
      if (status !== "awaiting_photos" && status !== "estimating") {
        throw new Error(`サブスクリプションを待っているにならず、${status} で終わった`);
      }
      return { waiting: status };
    },
  });
  options.log("推定がサブスクリプションを待っているになった");
};

// サインインしたあとの流れが失敗しても、アカウントを消してから投げる
const withAccountDeletion = async (
  options: MainFlowOptions,
  session: Session,
  flow: () => Promise<void>,
): Promise<void> => {
  try {
    await flow();
  } catch (error) {
    await deleteAccount(options, session).catch((deletionError: unknown) => {
      options.log(`アカウントの削除にも失敗した: ${describeError(deletionError)}`);
    });
    throw error;
  }
  await deleteAccount(options, session);
};

const requireSessionRevoked = async (options: MainFlowOptions, session: Session) => {
  const afterDeletion = await callApi(options, session, "GET", syncChangesPath(0));
  if (afterDeletion.status !== 401) {
    throw new Error(
      `アカウントを削除したあとも、セッションが使えた（状態コード ${afterDeletion.status}）`,
    );
  }
};

// サブスクリプションの状態の記録から、無料体験の最後の日を読む。無料体験が無ければ undefined。
// テストユーザーは無料体験によらず使えるので、確かめに使えない
const readFreeTrialLastDay = async (
  options: MainFlowOptions,
  session: Session,
): Promise<string | undefined> => {
  const record = (await pullAllChanges(options, session))
    .filter(({ kind }) => kind === "subscription_status")
    .at(-1)?.record;
  if (record === undefined) {
    throw new Error("サブスクリプションの状態の記録が、取りに行く応答に無い");
  }
  const status = z
    .discriminatedUnion("type", [
      z.object({ type: z.literal("test_user") }),
      z.object({
        type: z.literal("regular"),
        freeTrial: z.object({ type: z.string(), lastDay: z.string().optional() }),
      }),
    ])
    .parse(record);
  if (status.type === "test_user") {
    throw new Error("サインインしたアカウントがテストユーザーになっている");
  }
  return status.freeTrial.lastDay;
};

// 確かめのサインインはタイムゾーンを送らないので、使い始めた日と無料体験の最後の日は UTC の日付で数えられる
const computeTodayOfStartedOn = (): string => computeCalendarDayInTimeZone(new Date(), "UTC");

// signedInAt を渡すと、その時刻にサインインしたことにする（使い始めた日がその日になる）
const signIn = async (options: MainFlowOptions, signedInAt?: Date): Promise<Session> => {
  const response = await options.send(`${options.baseUrl}/v1/e2e/sessions`, {
    method: "POST",
    headers: {
      [e2eRequestHeaders.signInSecret]: options.signInSecret,
      ...(signedInAt === undefined
        ? {}
        : { [e2eRequestHeaders.requestedAt]: signedInAt.toISOString() }),
    },
  });
  if (response.status === 404) {
    throw new Error("サインインの口が閉じている（開発用の Worker に E2E_SIGN_IN_SECRET を置く）");
  }
  if (response.status === 401) {
    throw new Error(
      "サインインの秘密の値が合わない（GitHub の Environment と Worker の E2E_SIGN_IN_SECRET を同じにする）",
    );
  }
  if (response.status !== 201) {
    throw new Error(`サインインできなかった（状態コード ${response.status}）`);
  }
  return z.object({ sessionToken: z.string(), accountId: z.string() }).parse(await response.json());
};

const recordWeight = async (
  options: MainFlowOptions,
  session: Session,
  measuredAt: Date,
): Promise<void> => {
  await pushWrites(options, session, [
    {
      id: generateRecordId(),
      type: "create_weight_record",
      weightRecord: {
        id: generateRecordId(),
        weightKg: 60.5,
        measuredAt: measuredAt.getTime(),
        timeZone: "Asia/Tokyo",
      },
    },
  ]);
};

// 初めての目標を、端末と同じ順で決める。使い始めたばかりで食べた量の記録が無いので逆算できず、身体データを添えて式で出す。
// 減量の標準の案を、見せていた値のとおりに決め、同じ要求の ID の再送と、取りに行く応答に届くことまでを確かめる。
// 目標の設定の要求は、開発用の環境だけで受け付ける時刻の差し替えで、決めた時刻（decidedAt）に送ったことにする。決めた目標の ID を返す
const decideGoal = async (
  options: MainFlowOptions,
  session: Session,
  decidedAt: Date,
): Promise<string> => {
  const post = (path: GoalSetupPath, body: Record<string, unknown>) =>
    postGoalSetup(options, session, decidedAt, path, body);
  // 身体データは作り話にする（公開リポジトリ）。サーバーは計算に使ったら捨てる
  const bodyData = {
    sex: "female",
    heightCentimeters: 160,
    ageYears: 35,
    activity: { type: "level", level: "standing" },
  };

  const preview = goalSetupPreviewSchema.parse(await post("preview", { direction: "lose" }));
  if (preview.canBackCalculate !== false) {
    throw new Error(
      `食べた量の記録が無いのに、目標の下見が逆算できると答えた（canBackCalculate: ${String(preview.canBackCalculate)}）`,
    );
  }
  const previewWithBodyData = goalSetupPreviewSchema.parse(
    await post("preview", { direction: "lose", bodyData }),
  );
  if (previewWithBodyData.canOfferLoseProposals !== true) {
    throw new Error(
      `身体データを添えても、目標の下見が減量の案を出せると答えなかった（canOfferLoseProposals: ${String(previewWithBodyData.canOfferLoseProposals)}）`,
    );
  }
  options.log("目標の下見で、逆算できず、身体データを添えると減量の案を出せると答えた");

  // 期限は 13 週。開始の日は、サーバーが決めた日を目標案の応答から受け取って数える
  const decidedOn = computeCalendarDayInTimeZone(decidedAt, goalSetupTimeZone);
  const proposals = goalProposalsSchema.parse(
    await post("proposals", {
      plan: { direction: "lose", deadlineOn: addDays(decidedOn, 90) },
      bodyData,
    }),
  );
  if (proposals.direction !== "lose") {
    throw new Error(`減量の目標案を求めたのに、${proposals.direction} の目標案が返った`);
  }
  const standard = proposals.proposals.find(({ pace }) => pace === "standard");
  if (standard?.status !== "offered") {
    throw new Error(`目標案に、出せる標準の案が無い（${standard?.status ?? "枠が無い"}）`);
  }
  options.log(`目標案を受け取った（推定消費カロリーの出どころ ${proposals.expenditureSource}）`);

  const decisionRequest = {
    requestId: generateRecordId(),
    startedOn: proposals.startedOn,
    choice: {
      type: "proposal",
      direction: "lose",
      deadlineOn: proposals.deadlineOn,
      pace: "standard",
    },
    shown: { targetWeightKg: standard.targetWeightKg, dailyGuide: standard.dailyGuide },
    rejectedCustomTargetWeightCount: 0,
    bodyData,
  };
  const decision = await post("decisions", decisionRequest);
  const decided = goalDecisionSchema.parse(decision);
  if (decided.status !== "decided") {
    throw new Error(`目標が決まらず、${decided.status} が返った`);
  }
  const decidedKinds = decided.changes.map(({ kind }) => kind);
  if (decidedKinds.join("・") !== "goal・daily_guide・expenditure_estimate") {
    throw new Error(`決めた記録の並びが違う（${decidedKinds.join("・")}）`);
  }
  options.log(`7日前に目標を決めた（${decidedKinds.join("・")}）`);

  const resent = await post("decisions", decisionRequest);
  if (!isDeepStrictEqual(resent, decision)) {
    throw new Error("同じ要求の ID の再送が、初めの応答と違う応答で返った");
  }
  options.log("同じ要求の ID の再送が、同じ応答で返った");

  const pulled = await pullAllChanges(options, session);
  for (const change of decided.changes) {
    const pulledRecord = pulled
      .filter(({ kind, recordId }) => kind === change.kind && recordId === change.recordId)
      .at(-1)?.record;
    if (pulledRecord === undefined) {
      throw new Error(`決めた ${change.kind} の記録が、取りに行く応答に無い`);
    }
    if (!isDeepStrictEqual(pulledRecord, change.record)) {
      throw new Error(`取りに行った ${change.kind} の記録が、決めた応答の記録と食い違う`);
    }
  }
  options.log("取りに行くで目標と1日の目安と推定消費カロリーが届いた");
  const goalId = decided.changes.find(({ kind }) => kind === "goal")?.recordId;
  if (goalId === undefined) {
    throw new Error("決めた記録に目標が無い");
  }
  return goalId;
};

// 目標を決めたあとの取りに行く要求が、今週の月曜の週を見直し、その週の見直しの記録を、決めた目標に当てて届けることを確かめる。
// 使い始めて1週に満たないので、見送りになる見込み。見送りでも見直せても記録は1つ届くので、どちらになったかは知らせるだけにする
const requirePulledWeeklyReview = async (
  options: MainFlowOptions,
  session: Session,
  goalId: string,
): Promise<void> => {
  const thisMonday = computeStartOfWeek(
    computeCalendarDayInTimeZone(new Date(), createClientState().timeZone),
  );
  const weeklyReviews = (await pullAllChanges(options, session))
    .filter(({ kind }) => kind === "weekly_review")
    .map(({ record }) =>
      z
        .object({
          effectiveOn: z.string(),
          deferral: z.object({ reason: z.string(), goalId: z.string() }).optional(),
          review: z.object({ mainReason: z.string() }).optional(),
        })
        .parse(record),
    );
  const weeklyReview = weeklyReviews.find(({ effectiveOn }) => effectiveOn === thisMonday);
  if (weeklyReview === undefined) {
    throw new Error(
      `今週の月曜（${thisMonday}）の週の見直しが、取りに行く応答に無い（届いた週: ${weeklyReviews.map(({ effectiveOn }) => effectiveOn).join("・") || "なし"}）`,
    );
  }
  if (weeklyReview.deferral !== undefined && weeklyReview.deferral.goalId !== goalId) {
    throw new Error("見送った週の見直しが、決めた目標と違う目標に当たっている");
  }
  options.log(
    weeklyReview.deferral === undefined
      ? "取りに行くで週の見直しが届いた（見直せた）"
      : `取りに行くで週の見直しが届いた（見送りの理由 ${weeklyReview.deferral.reason}）`,
  );
};

const goalSetupTimeZone = "Asia/Tokyo";

type GoalSetupPath = "preview" | "proposals" | "decisions";

// 目標の設定の要求は同期の外でその場で答えるので、200 でなければ、断った理由（code）を添えて投げる
const postGoalSetup = async (
  options: MainFlowOptions,
  session: Session,
  requestedAt: Date,
  path: GoalSetupPath,
  body: Record<string, unknown>,
): Promise<unknown> => {
  const response = await callApi(options, session, "POST", `/v1/goal-setup/${path}`, {
    headers: {
      "content-type": "application/json",
      [e2eRequestHeaders.signInSecret]: options.signInSecret,
      [e2eRequestHeaders.requestedAt]: requestedAt.toISOString(),
    },
    body: JSON.stringify({ timeZone: goalSetupTimeZone, ...body }),
  });
  if (response.status !== 200) {
    const code = await response
      .json()
      .then((json) => z.object({ code: z.string() }).parse(json).code)
      .catch(() => "なし");
    throw new Error(
      `目標の設定の要求 ${path} が断られた（状態コード ${response.status}、理由: ${code}）`,
    );
  }
  return response.json();
};

const sendPhotographedMeal = async (
  options: MainFlowOptions,
  session: Session,
): Promise<string> => {
  const mealId = generateRecordId();
  const photoId = generateRecordId();
  const now = Date.now();
  await pushWrites(options, session, [
    {
      id: generateRecordId(),
      type: "create_meal",
      meal: {
        id: mealId,
        eatenAt: now - 60_000,
        eatenAtUtcOffsetSeconds: 32_400,
        sentAt: now,
        sentTimeZone: "Asia/Tokyo",
        entryMethod: "captured",
        photos: [{ id: photoId }],
      },
    },
  ]);
  const response = await callApi(options, session, "PUT", `/v1/meal-photos/${photoId}`, {
    headers: { "content-type": "image/jpeg" },
    body: options.photo,
  });
  if (response.status !== 204) {
    throw new Error(`写真を送れなかった（状態コード ${response.status}）`);
  }
  return mealId;
};

const waitForEstimation = (
  options: MainFlowOptions,
  session: Session,
  mealId: string,
): Promise<{ dishIds: [string, ...string[]]; ingredientCount: number }> =>
  waitForChanges(options, session, {
    goal: "推定できた",
    timeoutMs: options.estimationTimeoutMs,
    inspect: (changes) => inspectEstimation(options, session, changes, mealId),
  });

// 文章を読み分けて文章の食事ができ、その推定が終わるまで待つ。食事と読み分けられなければ失敗にする
const waitForWrittenMealEstimation = (
  options: MainFlowOptions,
  session: Session,
  sentTextId: string,
): Promise<{ dishIds: [string, ...string[]]; ingredientCount: number }> =>
  waitForChanges(options, session, {
    goal: "文章の食事が推定できた",
    timeoutMs: options.estimationTimeoutMs,
    inspect: (changes) => {
      const classification = findSentTextStatus(changes, sentTextId)?.classification ?? "未取得";
      if (classification !== "meal") {
        if (classification !== "pending" && classification !== "未取得") {
          throw new Error(`食事の文章が ${classification} と読み分けられた`);
        }
        return { waiting: `読み分け ${classification}` };
      }
      // 文章から食事がいくつできても、1つ目の食事（送った文章から先に作る食事）の推定を見る
      const mealId = changes
        .filter(({ kind }) => kind === "meal")
        .map(({ record }) =>
          z.object({ id: z.string(), sentTextId: z.string().optional() }).parse(record),
        )
        .find((meal) => meal.sentTextId === sentTextId)?.id;
      if (mealId === undefined) {
        throw new Error("食事と読み分けられたのに、文章の食事が無い");
      }
      return inspectEstimation(options, session, changes, mealId);
    },
  });

const inspectEstimation = async (
  options: MainFlowOptions,
  session: Session,
  changes: Change[],
  mealId: string,
): Promise<Inspection<{ dishIds: [string, ...string[]]; ingredientCount: number }>> => {
  const status = findEstimationStatus(changes, mealId) ?? "未取得";
  if (status === "estimated") {
    return { done: requireEstimatedDishIdsAndIngredientCount(changes, mealId) };
  }
  if (status === "failed") {
    throw new Error(
      `推定できたにならず、failed で終わった（${await describeLastEstimationAttempt(options, session, mealId)}）`,
    );
  }
  if (status !== "awaiting_photos" && status !== "estimating") {
    throw new Error(`推定できたにならず、${status} で終わった`);
  }
  return { waiting: status };
};

// 推定できなかった理由。同期の推定の状態は理由を持たないので、確かめのジョブのための口で最後に終わった試みを読む
const describeLastEstimationAttempt = async (
  options: MainFlowOptions,
  session: Session,
  mealId: string,
): Promise<string> => {
  const response = await callApi(
    options,
    session,
    "GET",
    `/v1/e2e/meals/${mealId}/last-estimation-attempt`,
    { headers: { [e2eRequestHeaders.signInSecret]: options.signInSecret } },
  );
  if (response.status !== 200) {
    return `最後の試みを読めなかった（状態コード ${response.status}）`;
  }
  const { lastEndedAttempt } = z
    .object({
      lastEndedAttempt: z
        .object({ result: z.string(), errorType: z.string().nullable() })
        .nullable(),
    })
    .parse(await response.json());
  if (lastEndedAttempt === null) {
    return "終わった試みが無い";
  }
  const { result, errorType } = lastEndedAttempt;
  return [
    `最後の試み: ${errorType === null ? result : `${result}、${errorType}`}`,
    // ワークスペースの月の支出の上限に当たったときも 400 になり、サーバーは見分けない。見分けるには Sentry の課題の題を読む
    ...(result === "bad_request"
      ? ["400 は開発用のワークスペースの月の支出の上限でも起きる。Sentry の課題の題で見分ける"]
      : []),
  ].join("。");
};

// 変更を取りに行き続け、inspect が終わったと言うまで待つ。inspect は、望まない結果で終わったら投げる
const waitForChanges = async <T>(
  options: MainFlowOptions,
  session: Session,
  wait: {
    goal: string;
    timeoutMs: number;
    inspect: (changes: Change[]) => Inspection<T> | Promise<Inspection<T>>;
  },
): Promise<T> => {
  const startedAt = Date.now();
  const changes: Change[] = [];
  let afterSequence = 0;
  let lastState = "未取得";
  while (Date.now() - startedAt < wait.timeoutMs) {
    const pulled = await pullChanges(options, session, afterSequence);
    changes.push(...pulled.changes);
    afterSequence = pulled.nextAfterSequence;
    if (pulled.hasMore) {
      continue;
    }
    const inspection = await wait.inspect(changes);
    if ("done" in inspection) {
      return inspection.done;
    }
    lastState = inspection.waiting;
    await new Promise((resolve) => setTimeout(resolve, options.pollIntervalMs));
  }
  throw new Error(
    `${wait.goal}にならないまま ${wait.timeoutMs} ミリ秒たった（最後の状態: ${lastState}）`,
  );
};

type Inspection<T> = { done: T } | { waiting: string };

const findEstimationStatus = (changes: Change[], mealId: string): string | undefined =>
  changes
    .filter(({ kind, recordId }) => kind === "meal_estimation_status" && recordId === mealId)
    .map(({ record }) => z.object({ status: z.string() }).parse(record).status)
    .at(-1);

// 推定できたなら、料理と材料が同期の変更に載っている。載っていなければ、状態だけが進んで中身が書かれていない
const requireEstimatedDishIdsAndIngredientCount = (
  changes: Change[],
  mealId: string,
): { dishIds: [string, ...string[]]; ingredientCount: number } => {
  const dishIds = changes
    .filter(({ kind }) => kind === "dish")
    .map(({ record }) => z.object({ id: z.string(), mealId: z.string() }).parse(record))
    .filter((dish) => dish.mealId === mealId)
    .map(({ id }) => id);
  const ingredientCount = changes
    .filter(({ kind }) => kind === "ingredient")
    .map(({ record }) => z.object({ dishId: z.string() }).parse(record))
    .filter(({ dishId }) => dishIds.includes(dishId)).length;
  const [firstDishId, ...restDishIds] = dishIds;
  if (firstDishId === undefined || ingredientCount === 0) {
    throw new Error(
      `推定できたのに、料理か材料が無い（料理 ${dishIds.length}、材料 ${ingredientCount}）`,
    );
  }
  return { dishIds: [firstDishId, ...restDishIds], ingredientCount };
};

// サーバーが振った料理の ID を、そのまま送り返して名前を直す。送り返した ID で料理が見つからないと、受け付けられずに失敗する（#362）
const renameEstimatedDish = async (
  options: MainFlowOptions,
  session: Session,
  dishId: string,
): Promise<void> => {
  await pushWrites(options, session, [
    { id: generateRecordId(), type: "update_dish", dishId, name: "直した料理" },
  ]);
};

const sendText = async (options: MainFlowOptions, session: Session, body: string) => {
  const sentTextId = generateRecordId();
  await pushWrites(options, session, [
    {
      id: generateRecordId(),
      type: "create_sent_text",
      sentText: { id: sentTextId, body, sentAt: Date.now(), timeZone: "Asia/Tokyo" },
    },
  ]);
  return sentTextId;
};

// 送った文章の見守る要求をつなぎ、閉じるまで読む。返事の ID のあとに本文が流れ、返事ありで閉じなければ失敗にする。
// つなぐ前に返事ができ終わっていると本文が流れないが、読み分けと返事でモデルを2回呼ぶあいだにつなげる見込み
const watchReply = async (
  options: MainFlowOptions,
  session: Session,
  sentTextId: string,
): Promise<StreamedReply> => {
  const signal = AbortSignal.timeout(options.replyTimeoutMs);
  const events = await (async () => {
    const response = await callApi(
      options,
      session,
      "GET",
      `/v1/sent-texts/${sentTextId}/reply-stream`,
      { signal },
    );
    if (response.status !== 200) {
      throw new Error(`見守る要求をつなげなかった（状態コード ${response.status}）`);
    }
    return readServerSentEvents(await response.text());
  })().catch((error: unknown) => {
    if (signal.aborted) {
      throw new Error(
        `会話の文章の見守る要求が ${options.replyTimeoutMs} ミリ秒のうちに閉じなかった`,
        { cause: error },
      );
    }
    throw error;
  });
  const lastEvent = events.at(-1);
  if (lastEvent?.type !== "replied") {
    throw new Error(
      `会話の文章の見守る要求が、返事ありでなく ${lastEvent === undefined ? "出来事なし" : JSON.stringify(lastEvent)} で閉じた`,
    );
  }
  if (!events.some(({ type }) => type === "reply_started")) {
    throw new Error("見守る要求をつないだときには返事ができ終わっていて、本文が流れなかった");
  }
  // 試みが途中で失敗すると、それまでの分を捨てて初めから流し直す
  const textDeltas = events.reduce<string[]>(
    (texts, event) =>
      event.type === "text_delta"
        ? [...texts, event.text]
        : event.type === "text_discarded"
          ? []
          : texts,
    [],
  );
  return {
    replyId: lastEvent.replyId,
    body: textDeltas.join(""),
    textDeltaCount: textDeltas.length,
  };
};

const readServerSentEvents = (text: string) =>
  text
    .split("\n\n")
    .flatMap((block) => block.split("\n").filter((line) => line.startsWith("data: ")))
    .map((line) => replyStreamEventSchema.parse(JSON.parse(line.slice("data: ".length))));

// 見守る要求で届いた返事が、取りに行く応答にも、送った文章の状態と返事の記録で届いていることを確かめる
const requirePulledReply = async (
  options: MainFlowOptions,
  session: Session,
  sentTextId: string,
  streamedReply: StreamedReply,
): Promise<void> => {
  const changes = await pullAllChanges(options, session);
  const replyStatus = findSentTextStatus(changes, sentTextId)?.replyStatus ?? "未取得";
  if (replyStatus !== "replied") {
    throw new Error(`見守る要求は返事ありで閉じたのに、取りに行くと応答の状態が ${replyStatus}`);
  }
  const utterance = changes
    .filter(({ kind }) => kind === "ai_utterance")
    .map(({ record }) =>
      z.object({ id: z.string(), body: z.string(), sentTextId: z.string() }).parse(record),
    )
    .find((record) => record.sentTextId === sentTextId);
  if (utterance === undefined) {
    throw new Error("見守る要求は返事ありで閉じたのに、取りに行くと返事が無い");
  }
  if (utterance.id !== streamedReply.replyId || utterance.body !== streamedReply.body) {
    throw new Error("取りに行った返事が、見守る要求で届いた返事と ID か本文で食い違う");
  }
};

const findSentTextStatus = (changes: Change[], sentTextId: string) =>
  changes
    .filter(({ kind, recordId }) => kind === "sent_text_status" && recordId === sentTextId)
    .map(({ record }) =>
      z.object({ classification: z.string(), replyStatus: z.string() }).parse(record),
    )
    .at(-1);

const pullAllChanges = async (options: MainFlowOptions, session: Session): Promise<Change[]> => {
  const changes: Change[] = [];
  let afterSequence = 0;
  for (;;) {
    const pulled = await pullChanges(options, session, afterSequence);
    changes.push(...pulled.changes);
    afterSequence = pulled.nextAfterSequence;
    if (!pulled.hasMore) {
      return changes;
    }
  }
};

const pullChanges = async (
  options: MainFlowOptions,
  session: Session,
  afterSequence: number,
): Promise<{ changes: Change[]; hasMore: boolean; nextAfterSequence: number }> => {
  const response = await callApi(options, session, "GET", syncChangesPath(afterSequence));
  if (response.status !== 200) {
    throw new Error(`変更を取りに行けなかった（状態コード ${response.status}）`);
  }
  return z
    .object({
      changes: z.array(
        z.object({
          sequence: z.number(),
          kind: z.string(),
          recordId: z.string(),
          record: z.record(z.string(), z.unknown()),
        }),
      ),
      hasMore: z.boolean(),
      nextAfterSequence: z.number(),
    })
    .parse(await response.json());
};

const pushWrites = async (
  options: MainFlowOptions,
  session: Session,
  writes: { id: string; type: string; [field: string]: unknown }[],
): Promise<void> => {
  const response = await callApi(options, session, "POST", "/v1/sync/writes", {
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ clientState: createClientState(), writes, isFinalBatch: false }),
  });
  if (response.status !== 200) {
    throw new Error(`書き込みを送れなかった（状態コード ${response.status}）`);
  }
  const { results } = z
    .object({
      results: z.array(z.object({ result: z.string(), rejectionReason: z.string().optional() })),
    })
    .parse(await response.json());
  for (const [index, { result, rejectionReason }] of results.entries()) {
    if (result !== "applied") {
      throw new Error(
        `書き込み ${writes[index]?.type} が ${result} になった（理由: ${rejectionReason ?? "なし"}）`,
      );
    }
  }
};

const deleteAccount = async (options: MainFlowOptions, session: Session): Promise<void> => {
  const response = await callApi(options, session, "DELETE", "/v1/account");
  if (response.status !== 204) {
    throw new Error(`アカウントを削除できなかった（状態コード ${response.status}）`);
  }
};

const callApi = (
  options: MainFlowOptions,
  session: Session,
  method: string,
  path: string,
  init: { headers?: Record<string, string>; body?: BodyInit; signal?: AbortSignal } = {},
): Promise<Response> =>
  options.send(`${options.baseUrl}${path}`, {
    method,
    headers: { ...init.headers, authorization: `Bearer ${session.sessionToken}` },
    ...(init.body === undefined ? {} : { body: init.body }),
    ...(init.signal === undefined ? {} : { signal: init.signal }),
  });

// 1回の流れは1台の端末として送る
const deviceId = generateRecordId();

const createClientState = () => ({
  deviceId,
  timeZone: "Asia/Tokyo",
  appVersion: "1.0.0",
  osVersion: "26.0",
  pendingWriteCount: 1,
  oldestPendingWriteAgeSeconds: 0,
  pendingPhotoCount: 0,
});

const syncChangesPath = (afterSequence: number): string => {
  const query = new URLSearchParams(
    Object.entries({ ...createClientState(), afterSequence }).map(([key, value]) => [
      key,
      String(value),
    ]),
  );
  return `/v1/sync/changes?${query.toString()}`;
};

const describeError = (error: unknown): string =>
  error instanceof Error ? error.message : String(error);

type MainFlowOptions = {
  baseUrl: string;
  signInSecret: string;
  photo: Uint8Array;
  send: (url: string, init: RequestInit) => Promise<Response>;
  // 推定は、写真の食事と文章の食事（読み分けを含む）のそれぞれで待つ
  estimationTimeoutMs: number;
  // 会話の文章を送ってから、見守る要求が返事ありで閉じるまで（読み分けと返事）
  replyTimeoutMs: number;
  pollIntervalMs: number;
  log: (message: string) => void;
};

type StreamedReply = { replyId: string; body: string; textDeltaCount: number };

type Session = { sessionToken: string; accountId: string };

type Change = { sequence: number; kind: string; recordId: string; record: Record<string, unknown> };
