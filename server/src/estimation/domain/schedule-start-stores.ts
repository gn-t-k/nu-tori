import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { MealPhotoStore } from "../../meal/domain/meal-photo-store";
import type { EstimationScheduleStore } from "./estimation-schedule-store";

// 待っている予定を、いつ始められるかを決めるのに読む置き場
export type ScheduleStartStores = {
  estimationSchedule: EstimationScheduleStore;
  mealPhoto: MealPhotoStore;
  dishEstimationStatus: DishEstimationStatusStore;
};
