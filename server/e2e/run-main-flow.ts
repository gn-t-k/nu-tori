import { z } from "zod";
import { mealTextBody } from "./meal-text-body";
import { generateRecordId } from "../src/domain/record-id";
import { replyStreamEventSchema } from "../src/http/reply-stream-routes/reply-stream-event-schema";

// 送る文章は作り話にする（公開リポジトリ）
const conversationTextBody = "今日はよく歩いたので、少し脚が疲れた";

// 開発用の環境へデプロイした Worker の本物の API を叩き、サインインから写真と文章の食事の推定、会話の文章への返事、アカウントの削除までを通す。
// 失敗したら、どの段で何が起きたかを書いて投げる。サインインしたあとは、失敗してもアカウントを消してから投げる
export const runMainFlow = async (options: MainFlowOptions): Promise<void> => {
  const session = await signIn(options);
  options.log("サインインした");
  try {
    await recordWeight(options, session);
    options.log("体重を記録した");
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
  } catch (error) {
    await deleteAccount(options, session).catch((deletionError: unknown) => {
      options.log(`アカウントの削除にも失敗した: ${describeError(deletionError)}`);
    });
    throw error;
  }
  await deleteAccount(options, session);
  options.log("アカウントを削除した");
  const afterDeletion = await callApi(options, session, "GET", syncChangesPath(0));
  if (afterDeletion.status !== 401) {
    throw new Error(
      `アカウントを削除したあとも、セッションが使えた（状態コード ${afterDeletion.status}）`,
    );
  }
};

const signIn = async (options: MainFlowOptions): Promise<Session> => {
  const response = await options.send(`${options.baseUrl}/v1/e2e/sessions`, {
    method: "POST",
    headers: { "x-e2e-sign-in-secret": options.signInSecret },
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

const recordWeight = async (options: MainFlowOptions, session: Session): Promise<void> => {
  await pushWrites(options, session, [
    {
      id: generateRecordId(),
      type: "create_weight_record",
      weightRecord: {
        id: generateRecordId(),
        weightKg: 60.5,
        measuredAt: Date.now(),
        timeZone: "Asia/Tokyo",
      },
    },
  ]);
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
    inspect: (changes) => inspectEstimation(changes, mealId),
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
      return inspectEstimation(changes, mealId);
    },
  });

const inspectEstimation = (
  changes: Change[],
  mealId: string,
): Inspection<{ dishIds: [string, ...string[]]; ingredientCount: number }> => {
  const status = findEstimationStatus(changes, mealId) ?? "未取得";
  if (status === "estimated") {
    return { done: requireEstimatedDishIdsAndIngredientCount(changes, mealId) };
  }
  if (status !== "awaiting_photos" && status !== "estimating") {
    throw new Error(`推定できたにならず、${status} で終わった`);
  }
  return { waiting: status };
};

// 変更を取りに行き続け、inspect が終わったと言うまで待つ。inspect は、望まない結果で終わったら投げる
const waitForChanges = async <T>(
  options: MainFlowOptions,
  session: Session,
  wait: { goal: string; timeoutMs: number; inspect: (changes: Change[]) => Inspection<T> },
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
    const inspection = wait.inspect(changes);
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
