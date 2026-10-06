import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { MealPhotoStore } from "../../meal/domain/meal-photo-store";
import { computeScheduleStartsAt } from "./compute-schedule-starts-at";
import type { EstimationScheduleStore, WaitingSchedule } from "./estimation-schedule-store";

// 待っている予定のうち、いま推定を始められるもの（早い順）。料理が対象の予定は、食事の写真がまだすべては届いていないあいだ、
// 写真を待つ時間を過ぎるまで待たせる（推定も見送りもせず、数えない）
export const findStartableSchedules = (stores: Stores, now: Date): WaitingSchedule[] =>
  stores.estimationSchedule
    .findWaitingSchedules(now)
    .filter((schedule) => computeScheduleStartsAt(stores, schedule).getTime() <= now.getTime());

type Stores = {
  estimationSchedule: EstimationScheduleStore;
  mealPhoto: MealPhotoStore;
  dishEstimationStatus: DishEstimationStatusStore;
};
