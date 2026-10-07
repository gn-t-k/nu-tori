import type { RecordId } from "../../domain/record-id";
import { computeMealEstimationStatus } from "./create-meal-estimation-status-kind";
import type { MealEstimationStatusStore } from "./meal-estimation-status-store";

// 食事が推定を待っているか（写真を待っている・推定中・翌日に推定）。待っている食事には、料理を足すことも、
// 料理と材料を直すこともできない（#381）。推定の状態は行を持たないので、今の表から毎回出す
export const mealAwaitsEstimation = (
  store: MealEstimationStatusStore,
  mealId: RecordId,
): boolean => {
  const status = computeMealEstimationStatus(store.findSchedulesOfMeal(mealId));
  return (
    status === "awaiting_photos" || status === "estimating" || status === "deferred_to_next_day"
  );
};
