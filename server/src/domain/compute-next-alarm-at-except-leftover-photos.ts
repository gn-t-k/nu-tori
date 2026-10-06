import { computeNextEstimationAttemptAt } from "../estimation/domain/compute-next-estimation-attempt-at";
import { findEarliestScheduleStartsAt } from "../estimation/domain/find-earliest-schedule-starts-at";
import type { RecordKindStores } from "./record-kind-stores";

// 写真の控えの消し残しを除いた、次のアラームの時刻。消し直しに失敗したアラームが、今に張り直さずに使う。どれも無ければ undefined。
// 1. 待っている推定の予定を始められる時刻（写真を待たせている料理の予定は、待つ時間を過ぎる時刻） 2. 続いている推定の、次に試みる時刻
export const computeNextAlarmAtExceptLeftoverPhotos = (
  stores: Pick<
    RecordKindStores,
    "estimationSchedule" | "estimation" | "mealPhoto" | "dishEstimationStatus"
  >,
): Date | undefined =>
  [
    findEarliestScheduleStartsAt(stores),
    ...stores.estimation
      .findContinuingEstimations()
      .map(({ attempts }) => computeNextEstimationAttemptAt(attempts)),
  ]
    .filter((candidate) => candidate !== undefined)
    .toSorted((a, b) => a.getTime() - b.getTime())[0];
