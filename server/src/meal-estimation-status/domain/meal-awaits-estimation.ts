import { match } from "ts-pattern";
import type { RecordId } from "../../domain/record-id";
import { computeMealEstimationStatus } from "./compute-meal-estimation-status";
import type { MealEstimationStatusStore } from "./meal-estimation-status-store";

// 食事が推定を待っているか（写真を待っている・推定中・翌日に推定）。待っている食事には、料理を足すことも、
// 料理と材料を直すこともできない（#381）。推定の状態は行を持たないので、今の表から毎回出す
export const mealAwaitsEstimation = (store: MealEstimationStatusStore, mealId: RecordId): boolean =>
  match(computeMealEstimationStatus(store.findSchedulesOfMeal(mealId)))
    .with("awaiting_photos", "estimating", "deferred_to_next_day", () => true)
    .with("estimated", "no_dishes", "failed", () => false)
    .exhaustive();
