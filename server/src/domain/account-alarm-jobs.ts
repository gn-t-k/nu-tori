import { advanceEstimations } from "../estimation/domain/advance-estimations";
import { computeNextEstimationAttemptAt } from "../estimation/domain/compute-next-estimation-attempt-at";
import type { EstimationProvider } from "../estimation/domain/estimation-provider";
import { deleteLeftoverMealPhotoFiles } from "../meal/domain/delete-leftover-meal-photo-files";
import type { MealPhotoArchive } from "../meal/domain/meal-photo-archive";
import { advanceReplies } from "../reply/domain/advance-replies";
import type { ConversationProvider } from "../reply/domain/conversation-provider";
import type { ReplyWatchers } from "../reply/domain/create-reply-watchers";
import { replyAttemptTimeLimitMs } from "../reply/domain/reply-attempt-time-limit-ms";
import { classifySentTexts } from "../sent-text/domain/classify-sent-texts";
import { advanceSubscriptionCheck } from "../subscription-status/domain/advance-subscription-check";
import { readSubscriptionCheck } from "../subscription-status/domain/read-subscription-check";
import type { AlarmJob } from "./alarm-job";
import { computeNextAttemptAt } from "./compute-next-attempt-at";
import { findEarliest } from "./find-earliest";
import type { RecordChangeWriter } from "./record-change-writer";
import type { RecordKindStores } from "./record-kind-stores";
import type { UsageEvent } from "./usage-event";

// アカウントのアラームで動かす仕事の並び。アラームはこの順に進め、エラーはこの順で先のものを報告する。
// アラームで動かすものを足すときは、ここに足す
export const accountAlarmJobs: readonly AlarmJob<
  RecordKindStores,
  AccountAlarmDeps,
  AccountAlarmReport
>[] = [
  // 課金。使えるようになっていれば保留した推定を再開するので、推定より先に置く
  {
    advance: async (stores, deps) => ({
      result: "advanced",
      report: {
        ...emptyReport,
        usageEvents: advanceSubscriptionCheck(deps.writeRecordChanges, stores, new Date()),
      },
    }),
    computeNextAt: (stores, now) => readSubscriptionCheck(stores, now)?.nextAt,
  },
  // 読み分け。食事と読み分けた文章の推定を同じアラームで始めるため、推定より先に置く
  {
    advance: async (stores, deps) => {
      const classified = await classifySentTexts(deps.writeRecordChanges, stores, {
        provider: deps.conversationProvider,
      });
      // 食事と読み分けた文章の見守る要求を閉じる
      deps.replyWatchers.refresh(stores);
      return { result: "advanced", report: { ...emptyReport, ...classified } };
    },
    // 読み分けを待っている文章を受け取った時刻（過ぎているので、すぐ動く）
    computeNextAt: (stores) =>
      findEarliest(stores.sentText.findUnclassified().map(({ receivedAt }) => receivedAt)),
  },
  // 推定
  {
    advance: async (stores, deps) => {
      const { stoppedError, ...advanced } = await advanceEstimations(
        deps.writeRecordChanges,
        stores,
        deps,
        new Date(),
      );
      return { ...toStoppable(stoppedError), report: { ...emptyReport, ...advanced } };
    },
    // 待っている推定の予定の時刻と、続いている推定の、次に試みる時刻
    computeNextAt: (stores) =>
      findEarliest([
        stores.estimationSchedule.findWaitingSchedules(undefined)[0]?.dueAt,
        ...stores.estimation
          .findContinuingEstimations()
          .map(({ attempts }) => computeNextEstimationAttemptAt(attempts)),
      ]),
  },
  // 返事。同じアラームで推定し終えた食事の栄養を返事の文脈に入れるため、推定のあとに置く
  {
    advance: async (stores, deps) => {
      const { stoppedError, attempts, ...replied } = await advanceReplies(
        deps.writeRecordChanges,
        stores,
        {
          provider: deps.conversationProvider,
          armAlarm: deps.armAlarm,
          watchers: deps.replyWatchers,
        },
        new Date(),
      );
      return {
        ...toStoppable(stoppedError),
        report: { ...emptyReport, ...replied, replyAttempts: attempts },
      };
    },
    // 待っている返事の依頼を作った時刻（過ぎているので、すぐ動く）と、続いている返事の生成の、次に試みる時刻
    computeNextAt: (stores) =>
      findEarliest([
        ...stores.reply.findWaitingRequests().map(({ requestedAt }) => requestedAt),
        ...stores.reply
          .findContinuingGenerations()
          .map(({ attempts }) => computeNextAttemptAt(attempts, replyAttemptTimeLimitMs)),
      ]),
  },
  // 写真の控えの消し残しの消し直し
  {
    advance: (stores, deps) =>
      deleteLeftoverMealPhotoFiles(stores.mealPhoto, deps.archive, new Date()).then(
        () => ({ result: "advanced", report: emptyReport }),
        // 今に張り直さず Cloudflare のアラームのやり直しに任せる。使い切ったら、次に予定を入れたときに消し直す
        (error: unknown) => ({ result: "left_to_alarm_retry", error, report: emptyReport }),
      ),
    // 消し残しがあれば今すぐ
    computeNextAt: (stores, now) =>
      stores.mealPhoto.findLeftoverPhotoIds().length > 0 ? now : undefined,
  },
];

type AccountAlarmDeps = {
  writeRecordChanges: RecordChangeWriter;
  archive: MealPhotoArchive;
  provider: EstimationProvider;
  conversationProvider: ConversationProvider;
  armAlarm: () => Promise<void>;
  replyWatchers: ReplyWatchers;
};

// 仕事ごとの報告。その仕事に無い欄は空にする
type AccountAlarmReport = {
  // Sentry に包まずに送る、提供元のエラー
  providerErrors: unknown[];
  usageEvents: UsageEvent[];
  // アラームの呼び出しごとのログに出す、呼び出しと試みごとの結果
  classifications: Awaited<ReturnType<typeof classifySentTexts>>["classifications"];
  attempts: Awaited<ReturnType<typeof advanceEstimations>>["attempts"];
  replyAttempts: Awaited<ReturnType<typeof advanceReplies>>["attempts"];
};

const emptyReport: AccountAlarmReport = {
  providerErrors: [],
  usageEvents: [],
  classifications: [],
  attempts: [],
  replyAttempts: [],
};

// 止まった試み（結果を書けずに投げた試み）があれば、ほかの試みの結果を書き終えてから報告する
const toStoppable = (stoppedError: unknown) =>
  stoppedError === undefined
    ? ({ result: "advanced" } as const)
    : ({ result: "stopped", error: stoppedError } as const);
