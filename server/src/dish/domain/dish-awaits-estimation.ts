import { dishAwaitsReestimation } from "../../dish-estimation-status/domain/dish-awaits-reestimation";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import { mealAwaitsEstimation } from "../../meal-estimation-status/domain/meal-awaits-estimation";
import type { MealEstimationStatusStore } from "../../meal-estimation-status/domain/meal-estimation-status-store";
import type { Dish } from "./dish";

// 料理が、食事の推定か自分の推定し直しを待っているか。待っている料理は、料理も材料も直せない（#381）
export const dishAwaitsEstimation = (
  stores: {
    mealEstimationStatus: MealEstimationStatusStore;
    dishEstimationStatus: DishEstimationStatusStore;
  },
  dish: Pick<Dish, "id" | "mealId">,
  now: Date,
): boolean =>
  mealAwaitsEstimation(stores.mealEstimationStatus, dish.mealId) ||
  dishAwaitsReestimation(stores.dishEstimationStatus, dish.id, now);
