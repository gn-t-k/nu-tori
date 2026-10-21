import type { DishStore } from "../../dish/domain/dish-store";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import type { MealStore } from "../../meal/domain/meal-store";
import type { MealEstimationStatusStore } from "../../meal-estimation-status/domain/meal-estimation-status-store";
import type { EstimationEventWriteStore } from "./estimation-event-write-store";
import type { EstimationScheduleStore } from "./estimation-schedule-store";
import type { EstimationStore } from "./estimation-store";
import type { EstimationWrites } from "./estimation-writes";
import { openEstimationEventWrites } from "./open-estimation-event-writes";

// 推定の書き込みの口。推定の予定と結果は、ここを通して書く。
// run が書いた食事・料理のうち、推定の状態が変わった記録にだけ、書いた順に推定の状態の変更を足す（open-estimation-event-writes.ts）。
// addChange は、記録の変化を書く入口か、書き込みの決定の commit に渡るもの。now は料理ごとの推定の状態を決める時刻
export const writeEstimationEvents = <T>(
  stores: {
    meal: MealStore;
    mealEstimationStatus: MealEstimationStatusStore;
    dish: DishStore;
    dishEstimationStatus: DishEstimationStatusStore;
    estimationEventWrite: EstimationEventWriteStore;
    estimation: EstimationStore;
    estimationSchedule: EstimationScheduleStore;
  },
  addChange: (
    change: RecordChangeTarget<"meal_estimation_status" | "dish_estimation_status">,
  ) => void,
  now: Date,
  run: (writes: EstimationWrites) => T,
): T => {
  const { writes, addStatusChanges } = openEstimationEventWrites(stores, addChange, now);
  const result = run(writes);
  addStatusChanges();
  return result;
};
