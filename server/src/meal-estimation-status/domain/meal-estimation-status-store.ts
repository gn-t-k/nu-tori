import type { RecordId } from "../../domain/record-id";
import type { MealEstimationScheduleProgress } from "./meal-estimation-schedule-progress";

export type MealEstimationStatusStore = {
  // 食事につながっている推定の予定ごとの、予定から先の出来事
  findSchedulesOfMeal: (mealId: RecordId) => MealEstimationSchedule[];
};

export type MealEstimationSchedule = { dueAt: Date } & MealEstimationScheduleState;

// 予定の進み具合。推定を始めた予定だけが、始めた推定を持つ
export type MealEstimationScheduleState =
  | { progress: Extract<MealEstimationScheduleProgress, "waiting" | "deferred" | "held"> }
  | {
      progress: Exclude<MealEstimationScheduleProgress, "waiting" | "deferred" | "held">;
      estimationId: string;
    };
