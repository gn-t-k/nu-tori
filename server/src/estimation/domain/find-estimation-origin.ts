import { findReceivedAtOfEstimation } from "../../dish-estimation-status/domain/dish-estimation-schedule";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { UsageEvent } from "../../domain/usage-event";
import type { EstimationScheduleStore } from "./estimation-schedule-store";
import type { EstimationTarget } from "./estimation-target";
import { findMealReceivedAt } from "./find-meal-received-at";

// 推定ごとの出来事に添える、推定のきっかけと、きっかけを受け取った時刻。
// 食事が対象なら写真がそろって予定に入れた時刻、料理が対象なら名前を直した書き込みを受け取った時刻
export const findEstimationOrigin = (
  stores: {
    estimationSchedule: EstimationScheduleStore;
    dishEstimationStatus: DishEstimationStatusStore;
  },
  target: EstimationTarget,
  estimationId: string,
): {
  trigger: Extract<UsageEvent, { name: "estimation_ended" }>["trigger"];
  receivedAt: Date;
} =>
  target.type === "meal"
    ? {
        trigger: "photo",
        receivedAt: findMealReceivedAt(stores.estimationSchedule, target.mealId),
      }
    : {
        trigger: "dish_renamed",
        receivedAt: findReceivedAtOfEstimation(
          stores.dishEstimationStatus.findSchedulesOfDish(target.dishId),
          estimationId,
        ),
      };
