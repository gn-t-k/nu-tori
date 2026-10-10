import { computeNextEstimationAttemptAt } from "../estimation/domain/compute-next-estimation-attempt-at";
import { replyAttemptTimeLimitMs } from "../reply/domain/reply-attempt-time-limit-ms";
import { computeNextAttemptAt } from "./compute-next-attempt-at";
import type { RecordKindStores } from "./record-kind-stores";

// 写真の控えの消し残しを除いた、次のアラームの時刻。消し直しに失敗したアラームが、今に張り直さずに使う。どれも無ければ undefined。
// 1. 読み分けを待っている文章を受け取った時刻（過ぎているので、すぐ動く） 2. 待っている推定の予定の時刻 3. 続いている推定の、次に試みる時刻
// 4. 待っている返事の依頼を作った時刻（過ぎているので、すぐ動く） 5. 続いている返事の生成の、次に試みる時刻
export const computeNextAlarmAtExceptLeftoverPhotos = (
  stores: Pick<RecordKindStores, "sentText" | "estimationSchedule" | "estimation" | "reply">,
): Date | undefined =>
  [
    ...stores.sentText.findUnclassified().map(({ receivedAt }) => receivedAt),
    stores.estimationSchedule.findWaitingSchedules(undefined)[0]?.dueAt,
    ...stores.estimation
      .findContinuingEstimations()
      .map(({ attempts }) => computeNextEstimationAttemptAt(attempts)),
    ...stores.reply.findWaitingRequests().map(({ requestedAt }) => requestedAt),
    ...stores.reply
      .findContinuingGenerations()
      .map(({ attempts }) => computeNextAttemptAt(attempts, replyAttemptTimeLimitMs)),
  ]
    .filter((candidate) => candidate !== undefined)
    .toSorted((a, b) => a.getTime() - b.getTime())[0];
