import type { RecordId } from "../../domain/record-id";
import type { MealEstimationScheduleState } from "./meal-estimation-schedule-progress";

export type MealEstimationStatusStore = {
  // 食事につながっている推定の予定ごとの、予定から先の出来事
  findSchedulesOfMeal: (mealId: RecordId) => ({ dueAt: Date } & MealEstimationScheduleState)[];
};
