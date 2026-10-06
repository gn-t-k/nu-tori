import type { DishStore } from "../../dish/domain/dish-store";
import { findOngoingEstimationId } from "../../dish-estimation-status/domain/dish-estimation-schedule";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { UsageEvent } from "../../domain/usage-event";
import { computeEstimationEndedEvent } from "./compute-estimation-ended-event";
import type { EstimationStore } from "./estimation-store";
import { findEstimationOrigin } from "./find-estimation-origin";
import type { EstimationScheduleStore } from "./estimation-schedule-store";

// 推定し直しの推定中に料理が消えるときの、推定ごとの出来事（消えたものの区分で送る）。
// 料理を消すとつなぎが CASCADE で消え、届いた推定は捨てられるので、消す書き込みを決めるときに読む
export const computeDishDeletedEstimationEvents = (
  stores: {
    dishEstimationStatus: DishEstimationStatusStore;
    estimationSchedule: EstimationScheduleStore;
    estimation: EstimationStore;
    dish: DishStore;
  },
  dish: { id: string; mealId: string },
  finalStatus: "dish_deleted" | "meal_deleted",
  deletedAt: Date,
): UsageEvent[] => {
  const estimationId = findOngoingEstimationId(
    stores.dishEstimationStatus.findSchedulesOfDish(dish.id),
  );
  if (estimationId === undefined) {
    return [];
  }
  return [
    computeEstimationEndedEvent({
      ...findEstimationOrigin(
        stores,
        { type: "dish", dishId: dish.id, mealId: dish.mealId },
        estimationId,
      ),
      finalStatus,
      attempts: stores.estimation.findAttempts(estimationId),
      endedAt: deletedAt,
      dishCount: 0,
      ingredients: [],
    }),
  ];
};
