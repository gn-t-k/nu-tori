import { R } from "@praha/byethrow";
import { sendsUsageData } from "../../account-settings/domain/sends-usage-data";
import { applySyncWrites } from "../../domain/apply-sync-writes";
import { computeNextAlarmAt } from "../../domain/compute-next-alarm-at";
import { pullSyncChanges } from "../../domain/pull-sync-changes";
import { receiveMealPhoto } from "../../domain/receive-meal-photo";
import { recordFirstSignIn } from "../../domain/record-first-sign-in";
import type { RecordId } from "../../domain/record-id";
import { runAccountAlarm } from "../../domain/run-account-alarm";
import type { SyncClientState } from "../../domain/sync-client-state";
import type { SyncWrite } from "../../domain/sync-write";
import { assessCustomTargetWeight } from "../../goal/domain/assess-custom-target-weight";
import { decideGoal } from "../../goal/domain/decide-goal";
import { previewGoalSetup } from "../../goal/domain/preview-goal-setup";
import { proposeGoals } from "../../goal/domain/propose-goals";
import { readKeptMealPhoto } from "../../meal/domain/read-kept-meal-photo";
import type { AccountResponse } from "./account-response";
import type { AccountStores } from "./account-stores";

// アカウントの Durable Object の受け口とアラームの、要求ごとの処理。
// どれも、張り直すアラームの時刻と、送るかどうかを決めた利用状況の出来事を一緒に返す
export const accountRequests = {
  recordFirstSignIn: (
    stores: Pick<AccountStores, "firstSignIn">,
    signIn: { signedInAt: Date; timeZone: string | undefined },
  ): AccountResponse<void> => {
    recordFirstSignIn(stores.firstSignIn, signIn);
    return respond(undefined);
  },

  pushSyncWrites: (
    stores: Pick<AccountStores, "ledger" | "records">,
    request: { clientState: SyncClientState; writes: SyncWrite[]; isFinalBatch: boolean },
    now: Date,
  ) => {
    const { results, usageEvents } = applySyncWrites(stores.ledger, stores.records, {
      ...request,
      receivedAt: now,
    });
    return {
      result: results,
      nextAlarmAt: computeNextAlarmAt(stores.records, now),
      usageEvents,
    } satisfies AccountResponse<unknown>;
  },

  pullSyncChanges: (
    stores: Pick<AccountStores, "ledger" | "records">,
    request: { clientState: SyncClientState; afterSequence: number },
    now: Date,
  ) => {
    const { usageEvents, ...pulled } = pullSyncChanges(stores.ledger, stores.records, {
      ...request,
      receivedAt: now,
    });
    return {
      result: pulled,
      nextAlarmAt: undefined,
      usageEvents,
    } satisfies AccountResponse<unknown>;
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
      usageEvents:
        R.isFailure(received) && sendsUsageData(stores.records.accountSettings)
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

  // 目標の設定の、その場で答える要求。下の3つは記録を書かない
  previewGoalSetup: (
    stores: Pick<AccountStores, "records">,
    request: Parameters<typeof previewGoalSetup>[1],
    now: Date,
  ) => respond(previewGoalSetup(stores.records, request, now)),

  proposeGoals: (
    stores: Pick<AccountStores, "records">,
    request: Parameters<typeof proposeGoals>[1],
    now: Date,
  ) => respond(proposeGoals(stores.records, request, now)),

  assessCustomTargetWeight: (
    stores: Pick<AccountStores, "records">,
    request: Parameters<typeof assessCustomTargetWeight>[1],
    now: Date,
  ) => respond(assessCustomTargetWeight(stores.records, request, now)),

  decideGoal: (
    stores: Pick<AccountStores, "writeRecordChanges" | "records">,
    request: Parameters<typeof decideGoal>[2],
    now: Date,
  ) => {
    const decided = decideGoal(stores.writeRecordChanges, stores.records, request, now);
    return {
      result: R.pipe(
        decided,
        R.map(({ decision }) => decision),
      ),
      nextAlarmAt: undefined,
      usageEvents: R.isSuccess(decided) ? decided.value.usageEvents : [],
    } satisfies AccountResponse<unknown>;
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
