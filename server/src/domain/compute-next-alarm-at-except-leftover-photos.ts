import { computeNextEstimationAttemptAt } from "../estimation/domain/compute-next-estimation-attempt-at";
import type { RecordKindStores } from "./record-kind-stores";

// 写真の控えの消し残しを除いた、次のアラームの時刻。消し直しに失敗したアラームが、今に張り直さずに使う。どれも無ければ undefined。
// 1. 読み分けを待っている文章を受け取った時刻（過ぎているので、すぐ動く） 2. 待っている推定の予定の時刻 3. 続いている推定の、次に試みる時刻
export const computeNextAlarmAtExceptLeftoverPhotos = (
  stores: Pick<RecordKindStores, "sentText" | "estimationSchedule" | "estimation">,
): Date | undefined =>
  [
    ...stores.sentText.findUnclassified().map(({ receivedAt }) => receivedAt),
    stores.estimationSchedule.findWaitingSchedules(undefined)[0]?.dueAt,
    ...stores.estimation
      .findContinuingEstimations()
      .map(({ attempts }) => computeNextEstimationAttemptAt(attempts)),
  ]
    .filter((candidate) => candidate !== undefined)
    .toSorted((a, b) => a.getTime() - b.getTime())[0];
