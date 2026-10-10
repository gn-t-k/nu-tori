import type { DishStore } from "../../dish/domain/dish-store";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { UsageEvent } from "../../domain/usage-event";
import type { MealStore } from "../../meal/domain/meal-store";
import type { EstimationScheduleStore } from "./estimation-schedule-store";
import type { EstimationTarget } from "./estimation-target";
import { findDishEstimationOrigin } from "./find-dish-estimation-origin";
import { findMealEstimationTrigger } from "./find-meal-estimation-trigger";
import { findMealReceivedAt } from "./find-meal-received-at";

// 推定ごとの出来事に添える、推定のきっかけと、きっかけを受け取った時刻。
// 食事が対象なら写真がそろって（文章の食事は読み分けて）予定に入れた時刻、料理が対象なら名前を直した・料理を足した書き込みを受け取った時刻。
// 料理が対象のきっかけは、使う人が足した料理の、いちばん早い予定から始まった推定なら料理を足した、ほかは名前を直した
// （料理を足す書き込みは料理の最初の予定を入れ、名前を直す書き込みはそのあとの予定を入れる）
export const findEstimationOrigin = (
  stores: {
    estimationSchedule: EstimationScheduleStore;
    dishEstimationStatus: DishEstimationStatusStore;
    dish: DishStore;
    meal: MealStore;
  },
  target: EstimationTarget,
  estimationId: string,
): {
  trigger: Extract<UsageEvent, { name: "estimation_ended" }>["trigger"];
  receivedAt: Date;
} =>
  target.type === "meal"
    ? {
        trigger: findMealEstimationTrigger(stores.meal, target.mealId),
        receivedAt: findMealReceivedAt(stores.estimationSchedule, target.mealId),
      }
    : findDishEstimationOrigin(stores, target.dishId, estimationId);
