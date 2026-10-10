import { findReceivedAtOfEstimation } from "../../dish-estimation-status/domain/dish-estimation-schedule";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { RecordId } from "../../domain/record-id";
import type { DishStore } from "../../dish/domain/dish-store";

// 料理が対象の推定（推定し直し）のきっかけと、きっかけを受け取った時刻
export const findDishEstimationOrigin = (
  stores: { dishEstimationStatus: DishEstimationStatusStore; dish: DishStore },
  dishId: RecordId,
  estimationId: string,
): { trigger: "dish_added" | "dish_renamed"; receivedAt: Date } => {
  const schedules = stores.dishEstimationStatus.findSchedulesOfDish(dishId);
  const receivedAt = findReceivedAtOfEstimation(schedules, estimationId);
  const startsFromFirstSchedule = schedules.every(
    ({ dueAt }) => dueAt.getTime() >= receivedAt.getTime(),
  );
  return {
    trigger:
      startsFromFirstSchedule && stores.dish.wasAddedByUser(dishId) ? "dish_added" : "dish_renamed",
    receivedAt,
  };
};
