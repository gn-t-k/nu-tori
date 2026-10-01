import { z } from "zod";

// 開発用の環境へデプロイした Worker の本物の API を叩き、サインインから推定、アカウントの削除までを通す。
// 失敗したら、どの段で何が起きたかを書いて投げる。サインインしたあとは、失敗してもアカウントを消してから投げる
export const runMainFlow = async (options: MainFlowOptions): Promise<void> => {
  const session = await signIn(options);
  options.log("サインインした");
  try {
    await recordWeight(options, session);
    options.log("体重を記録した");
    const mealId = await sendPhotographedMeal(options, session);
    options.log("写真の食事を送った");
    const { dishCount, ingredientCount } = await waitForEstimation(options, session, mealId);
    options.log(`推定できた（料理 ${dishCount}、材料 ${ingredientCount}）`);
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
      id: crypto.randomUUID(),
      type: "create_weight_record",
      weightRecord: {
        id: crypto.randomUUID(),
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
  const mealId = crypto.randomUUID();
  const photoId = crypto.randomUUID();
  const now = Date.now();
  await pushWrites(options, session, [
    {
      id: crypto.randomUUID(),
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

const waitForEstimation = async (
  options: MainFlowOptions,
  session: Session,
  mealId: string,
): Promise<{ dishCount: number; ingredientCount: number }> => {
  const startedAt = Date.now();
  const changes: Change[] = [];
  let afterSequence = 0;
  let lastStatus = "未取得";
  while (Date.now() - startedAt < options.estimationTimeoutMs) {
    const pulled = await pullChanges(options, session, afterSequence);
    changes.push(...pulled.changes);
    afterSequence = pulled.nextAfterSequence;
    if (pulled.hasMore) {
      continue;
    }
    lastStatus = findEstimationStatus(changes, mealId) ?? lastStatus;
    if (lastStatus === "estimated") {
      return countDishesAndIngredients(changes, mealId);
    }
    if (lastStatus !== "awaiting_photos" && lastStatus !== "estimating") {
      throw new Error(`推定できたにならず、${lastStatus} で終わった`);
    }
    await new Promise((resolve) => setTimeout(resolve, options.pollIntervalMs));
  }
  throw new Error(
    `推定できたにならないまま ${options.estimationTimeoutMs} ミリ秒たった（最後の状態: ${lastStatus}）`,
  );
};

const findEstimationStatus = (changes: Change[], mealId: string): string | undefined =>
  changes
    .filter(({ kind, recordId }) => kind === "meal_estimation_status" && recordId === mealId)
    .map(({ record }) => z.object({ status: z.string() }).parse(record).status)
    .at(-1);

// 推定できたなら、料理と材料が同期の変更に載っている。載っていなければ、状態だけが進んで中身が書かれていない
const countDishesAndIngredients = (
  changes: Change[],
  mealId: string,
): { dishCount: number; ingredientCount: number } => {
  const dishIds = changes
    .filter(({ kind }) => kind === "dish")
    .map(({ record }) => z.object({ id: z.string(), mealId: z.string() }).parse(record))
    .filter((dish) => dish.mealId === mealId)
    .map(({ id }) => id);
  const ingredientCount = changes
    .filter(({ kind }) => kind === "ingredient")
    .map(({ record }) => z.object({ dishId: z.string() }).parse(record))
    .filter(({ dishId }) => dishIds.includes(dishId)).length;
  if (dishIds.length === 0 || ingredientCount === 0) {
    throw new Error(
      `推定できたのに、料理か材料が無い（料理 ${dishIds.length}、材料 ${ingredientCount}）`,
    );
  }
  return { dishCount: dishIds.length, ingredientCount };
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
  init: { headers?: Record<string, string>; body?: BodyInit } = {},
): Promise<Response> =>
  options.send(`${options.baseUrl}${path}`, {
    method,
    headers: { ...init.headers, authorization: `Bearer ${session.sessionToken}` },
    ...(init.body === undefined ? {} : { body: init.body }),
  });

const createClientState = () => ({
  deviceId: "e2e-main-flow",
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
  estimationTimeoutMs: number;
  pollIntervalMs: number;
  log: (message: string) => void;
};

type Session = { sessionToken: string; accountId: string };

type Change = { sequence: number; kind: string; recordId: string; record: Record<string, unknown> };
