import type { RecordId } from "../../domain/record-id";
import type { EstimationSchedule } from "../../estimation/domain/estimation-schedule";

export type MealEstimationStatusStore = {
  // 食事につながっている推定の予定ごとの、予定から先の出来事
  findSchedulesOfMeal: (mealId: RecordId) => EstimationSchedule[];
};
