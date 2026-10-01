import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { MealStore } from "../../meal/domain/meal-store";
import type { MealEstimationStatus } from "./meal-estimation-status";
import type { MealEstimationStatusStore } from "./meal-estimation-status-store";

// 推定の状態の種類。サーバーだけが書く。記録の ID は食事の ID で、食事が消えたら削除の印を返す
export const createMealEstimationStatusKind = (
  mealStore: MealStore,
  store: MealEstimationStatusStore,
): RecordKind<"meal_estimation_status", never, MealEstimationStatus> => ({
  name: "meal_estimation_status",
  writes: undefined,
  readCurrent: (mealId): CurrentRecord<MealEstimationStatus> => {
    if (mealStore.find(mealId) === undefined) {
      return mealStore.hasDeletion(mealId) ? { status: "deleted" } : { status: "absent" };
    }
    return {
      status: "value",
      value: computeMealEstimationStatus(store.findSchedulesOfMeal(mealId)),
    };
  },
});

const computeMealEstimationStatus = (
  schedules: ReturnType<MealEstimationStatusStore["findSchedulesOfMeal"]>,
): MealEstimationStatus => {
  const latest = schedules.toSorted((a, b) => b.dueAt.getTime() - a.dueAt.getTime())[0];
  if (latest === undefined) {
    return "awaiting_photos";
  }
  if (!latest.isStarted) {
    // 見送ると次の日の予定を足すので、見送ったのはいちばん新しい予定より前の予定
    return schedules.some(({ isDeferred }) => isDeferred) ? "deferred_to_next_day" : "estimating";
  }
  if (latest.completion !== undefined) {
    return latest.completion;
  }
  return latest.isAbandoned ? "failed" : "estimating";
};
