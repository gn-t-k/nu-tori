import { R } from "@praha/byethrow";
import { applySyncWrites } from "../../domain/apply-sync-writes";
import { computeNextAlarmAt } from "../../domain/compute-next-alarm-at";
import { pullSyncChanges } from "../../domain/pull-sync-changes";
import { receiveMealPhoto } from "../../domain/receive-meal-photo";
import { recordFirstSignIn } from "../../domain/record-first-sign-in";
import type { RecordId } from "../../domain/record-id";
import { runAccountAlarm } from "../../domain/run-account-alarm";
import type { SyncClientState } from "../../domain/sync-client-state";
import type { SyncWrite } from "../../domain/sync-write";
import type { UsageEvent } from "../../domain/usage-event";
import { assessCustomTargetWeight } from "../../goal/domain/assess-custom-target-weight";
import { decideGoal } from "../../goal/domain/decide-goal";
import { judgeGoalProgress } from "../../goal/domain/judge-goal-progress";
import { previewGoalSetup } from "../../goal/domain/preview-goal-setup";
import { proposeGoals } from "../../goal/domain/propose-goals";
import { readKeptMealPhoto } from "../../meal/domain/read-kept-meal-photo";
import { reviewUnreviewedWeeks } from "../../weekly-review/domain/review-unreviewed-weeks";
import type { AccountResponse, LoggedAccountResponse } from "./account-response";
import type { AccountStores } from "./account-stores";

// アカウントの Durable Object の受け口とアラームの、要求ごとの処理。
// どれも、張り直すアラームの時刻と、起きた利用状況の出来事を一緒に返す（送るかどうかは Durable Object が送る前に決める）
export const accountRequests = {
  recordFirstSignIn: (
    stores: Pick<AccountStores, "firstSignIn">,
    signIn: { signedInAt: Date; timeZone: string | undefined },
  ): AccountResponse<void> => {
    recordFirstSignIn(stores.firstSignIn, signIn);
    return respond(undefined);
  },

  // 送り待ちを送り切った印のある要求だけ、送った記録を当ててから、目標の経過とまだ見直していない週を見る
  pushSyncWrites: (
    stores: Pick<AccountStores, "ledger" | "records" | "writeRecordChanges">,
    request: { clientState: SyncClientState; writes: SyncWrite[]; isFinalBatch: boolean },
    now: Date,
  ) => {
    const { results, usageEvents } = applySyncWrites(stores.ledger, stores.records, {
      ...request,
      receivedAt: now,
    });
    const caughtUp = request.isFinalBatch
      ? catchUpGoalProgress(stores, { timeZone: request.clientState.timeZone, now })
      : { reviewedWeekCount: undefined, usageEvents: [] };
    return {
      result: results,
      nextAlarmAt: computeNextAlarmAt(stores.records, now),
      usageEvents: [...usageEvents, ...caughtUp.usageEvents],
      requestLog: { reviewedWeekCount: caughtUp.reviewedWeekCount },
    } satisfies LoggedAccountResponse<unknown>;
  },

  // 見直しで変えた記録を同じ応答で届けるため、取りに行く前に見る
  pullSyncChanges: (
    stores: Pick<AccountStores, "ledger" | "records" | "writeRecordChanges">,
    request: { clientState: SyncClientState; afterSequence: number },
    now: Date,
  ) => {
    const caughtUp = catchUpGoalProgress(stores, {
      timeZone: request.clientState.timeZone,
      now,
    });
    const { usageEvents, ...pulled } = pullSyncChanges(stores.ledger, stores.records, {
      ...request,
      receivedAt: now,
    });
    return {
      result: pulled,
      nextAlarmAt: undefined,
      usageEvents: [...caughtUp.usageEvents, ...usageEvents],
      requestLog: { reviewedWeekCount: caughtUp.reviewedWeekCount },
    } satisfies LoggedAccountResponse<unknown>;
  },

  // 受け取れなかったら、失敗した段を出来事に載せ、アラームは張り直さない
  receiveMealPhoto: async (
    stores: Pick<AccountStores, "writeRecordChanges" | "records" | "mealPhotoArchive">,
    request: { photoId: RecordId; photo: ArrayBuffer },
    now: Date,
  ) => {
    const received = await receiveMealPhoto(
      stores.writeRecordChanges,
      stores.records,
      stores.mealPhotoArchive,
      { ...request, receivedAt: now },
    );
    return {
      result: received,
      nextAlarmAt: R.isSuccess(received) ? computeNextAlarmAt(stores.records, now) : undefined,
      usageEvents: R.isFailure(received)
        ? [{ name: "meal_photo_receipt_failed", stage: received.error.stage }]
        : [],
    } satisfies AccountResponse<unknown>;
  },

  readMealPhoto: async (
    stores: Pick<AccountStores, "records" | "mealPhotoArchive">,
    photoId: RecordId,
  ): Promise<AccountResponse<ArrayBuffer | undefined>> =>
    respond(await readKeptMealPhoto(stores.records.mealPhoto, stores.mealPhotoArchive, photoId)),

  watchReply: (
    stores: Pick<AccountStores, "openReplyStream">,
    sentTextId: RecordId,
  ): AccountResponse<ReadableStream<Uint8Array> | undefined> =>
    respond(stores.openReplyStream(sentTextId)),

  // 目標の設定の、その場で答える要求。どれも、まだ見直していない週を先に見て、その新しい状態から答える。
  // 下の3つは、見直しのほかは記録を書かない
  previewGoalSetup: (
    stores: Pick<AccountStores, "records" | "writeRecordChanges">,
    request: Parameters<typeof previewGoalSetup>[1],
    now: Date,
  ) => answerGoalSetup(stores, request, now, previewGoalSetup),

  proposeGoals: (
    stores: Pick<AccountStores, "records" | "writeRecordChanges">,
    request: Parameters<typeof proposeGoals>[1],
    now: Date,
  ) => answerGoalSetup(stores, request, now, proposeGoals),

  assessCustomTargetWeight: (
    stores: Pick<AccountStores, "records" | "writeRecordChanges">,
    request: Parameters<typeof assessCustomTargetWeight>[1],
    now: Date,
  ) => answerGoalSetup(stores, request, now, assessCustomTargetWeight),

  // 月曜に立て直すと、その月曜の見直しは前の目標に当たり、新しい目標はそのあとに決める
  decideGoal: (
    stores: Pick<AccountStores, "writeRecordChanges" | "records">,
    request: Parameters<typeof decideGoal>[2],
    now: Date,
  ) => {
    const caughtUp = catchUpGoalProgress(stores, { timeZone: request.timeZone, now });
    const decided = decideGoal(stores.writeRecordChanges, stores.records, request, now);
    return {
      result: R.pipe(
        decided,
        R.map(({ decision }) => decision),
      ),
      nextAlarmAt: undefined,
      usageEvents: [
        ...caughtUp.usageEvents,
        ...(R.isSuccess(decided) ? decided.value.usageEvents : []),
      ],
      requestLog: { reviewedWeekCount: caughtUp.reviewedWeekCount },
    } satisfies LoggedAccountResponse<unknown>;
  },

  deleteRecords: async (
    stores: Pick<AccountStores, "eraseRecords">,
  ): Promise<AccountResponse<void>> => {
    await stores.eraseRecords();
    return respond(undefined);
  },

  // アラーム1回分。result は、Durable Object が Sentry とログに出し、投げるもの
  runAlarm: async (
    stores: Pick<
      AccountStores,
      | "writeRecordChanges"
      | "records"
      | "mealPhotoArchive"
      | "estimationProvider"
      | "conversationProvider"
      | "replyWatchers"
      | "armAlarmAt"
    >,
  ) => {
    const { nextAlarmAt, usageEvents, ...ran } = await runAccountAlarm(
      stores.writeRecordChanges,
      stores.records,
      {
        archive: stores.mealPhotoArchive,
        provider: stores.estimationProvider,
        conversationProvider: stores.conversationProvider,
        armAlarm: () => armNextAlarm(stores),
        replyWatchers: stores.replyWatchers,
      },
    );
    return { result: ran, nextAlarmAt, usageEvents } satisfies AccountResponse<unknown>;
  },
};

// 記録を当てたあと、応える前に、達成と期限の日の結果を判定し、まだ見直していない週を古い順に見直す
const catchUpGoalProgress = (
  stores: Pick<AccountStores, "records" | "writeRecordChanges">,
  situation: { timeZone: string; now: Date },
): { reviewedWeekCount: number; usageEvents: UsageEvent[] } => {
  const judged = judgeGoalProgress(stores.writeRecordChanges, stores.records, situation);
  const reviewed = reviewUnreviewedWeeks(stores.writeRecordChanges, stores.records, situation);
  return {
    reviewedWeekCount: reviewed.reviewedWeekCount,
    usageEvents: [...judged.usageEvents, ...reviewed.usageEvents],
  };
};

// 目標の設定の、見直しのほかは記録を書かずに答える要求。まだ見直していない週を先に見て、その新しい状態から答える
const answerGoalSetup = <Request extends { timeZone: string }, Result>(
  stores: Pick<AccountStores, "records" | "writeRecordChanges">,
  request: Request,
  now: Date,
  answer: (records: AccountStores["records"], request: Request, now: Date) => Result,
): LoggedAccountResponse<Result> => {
  const caughtUp = catchUpGoalProgress(stores, { timeZone: request.timeZone, now });
  return {
    ...respond(answer(stores.records, request, now)),
    usageEvents: caughtUp.usageEvents,
    requestLog: { reviewedWeekCount: caughtUp.reviewedWeekCount },
  };
};

// 張り直すものも送るものも無い答え
const respond = <Result>(result: Result): AccountResponse<Result> => ({
  result,
  nextAlarmAt: undefined,
  usageEvents: [],
});

const armNextAlarm = async (
  stores: Pick<AccountStores, "records" | "armAlarmAt">,
): Promise<void> => {
  const alarmAt = computeNextAlarmAt(stores.records, new Date());
  if (alarmAt !== undefined) {
    await stores.armAlarmAt(alarmAt);
  }
};
