import { match } from "ts-pattern";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { findLatestValidTimeZone } from "../../domain/find-latest-valid-time-zone";
import { generateRecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import { isSubscriptionExpired } from "../../subscription-status/domain/is-subscription-expired";
import { readSubscriptionStatus } from "../../subscription-status/domain/read-subscription-status";
import type { EstimationTarget } from "./estimation-target";
import type { EstimationWrites } from "./estimation-writes";

// 保留した推定を再開する（#647 の「推定と返事」の「再開」）。推定の書き込みの口の中で呼ぶ。
// いちばん新しい予定が保留の食事・料理ごとに、数える日を今日（ユーザーの最新のタイムゾーン、読めなければ食事を送ったときのもの）、時刻を今にした新しい予定を足す。今日の分で使えない（サブスクリプション切れの）ときは足さない。
// その日の推定の回数を使い切っていれば、足した予定はアラームが翌日に見送る。再開した対象を、足した順に返す
export const resumeHeldEstimations = (
  stores: Pick<
    RecordKindStores,
    "estimationSchedule" | "latestTimeZone" | "meal" | "subscriptionStatus"
  >,
  writes: EstimationWrites,
  now: Date,
): EstimationTarget[] => {
  const heldTargets = stores.estimationSchedule.findHeldTargets();
  if (heldTargets.length === 0) {
    return [];
  }
  const status = readSubscriptionStatus(stores.subscriptionStatus);
  const latestTimeZone = findLatestValidTimeZone(stores.latestTimeZone);
  const resumed: EstimationTarget[] = [];
  for (const target of heldTargets) {
    const meal = stores.meal.find(target.mealId);
    if (meal === undefined) {
      throw new Error(`保留した予定につながっている食事が無い: ${target.mealId}`);
    }
    const countedOn = computeCalendarDayInTimeZone(now, latestTimeZone ?? meal.sentTimeZone);
    if (isSubscriptionExpired(status, { countedOn, at: now })) {
      continue;
    }
    const schedule = { id: generateRecordId(), dueAt: now, countedOn };
    match(target)
      .with({ type: "meal" }, ({ mealId }) => {
        writes.scheduleMeal({ ...schedule, mealId });
      })
      .with({ type: "dish" }, ({ dishId }) => {
        writes.scheduleDish({ ...schedule, dishId });
      })
      .exhaustive();
    resumed.push(target);
  }
  return resumed;
};
