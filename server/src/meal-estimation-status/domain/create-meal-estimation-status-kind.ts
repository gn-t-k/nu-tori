import { createServerOnlyKind } from "../../domain/sync-ledger/create-server-only-kind";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { MealStore } from "../../meal/domain/meal-store";
import { computeMealEstimationStatus } from "./compute-meal-estimation-status";
import type { MealEstimationStatus } from "./meal-estimation-status";
import type { MealEstimationStatusStore } from "./meal-estimation-status-store";

// 推定の状態の種類。サーバーだけが書く。記録の ID は食事の ID で、食事が消えたら削除の印を返す
export const createMealEstimationStatusKind = (
  mealStore: MealStore,
  store: MealEstimationStatusStore,
): RecordKind<"meal_estimation_status", never, MealEstimationStatus> =>
  createServerOnlyKind({
    name: "meal_estimation_status",
    whenGone: "deletion_mark",
    parent: {
      exists: (mealId) => mealStore.find(mealId) !== undefined,
      hasDeletion: mealStore.hasDeletion,
    },
    find: (mealId) => computeMealEstimationStatus(store.findSchedulesOfMeal(mealId)),
  });
