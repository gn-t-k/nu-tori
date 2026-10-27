import { computeEstimationStatus } from "../../estimation/domain/compute-estimation-status";
import type { EstimationSchedule } from "../../estimation/domain/estimation-schedule";
import type { MealEstimationStatus } from "./meal-estimation-status";

// 食事の推定の状態。予定がまだ無い食事は、写真がそろうのを待っている
export const computeMealEstimationStatus = (
  schedules: readonly EstimationSchedule[],
): MealEstimationStatus => computeEstimationStatus(schedules) ?? "awaiting_photos";
