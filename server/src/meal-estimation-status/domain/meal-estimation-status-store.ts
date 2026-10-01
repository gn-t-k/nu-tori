import type { MealEstimationScheduleProgress } from "./meal-estimation-schedule-progress";

export type MealEstimationStatusStore = {
  // 食事につながっている推定の予定ごとの、予定から先の出来事
  findSchedulesOfMeal: (mealId: string) => {
    dueAt: Date;
    progress: MealEstimationScheduleProgress;
  }[];
};
