import type { RecordId } from "../../domain/record-id";
import type { MealStore } from "../../meal/domain/meal-store";

// 食事が対象の推定のきっかけ。文章の食事なら文章、ほかは写真
export const findMealEstimationTrigger = (store: MealStore, mealId: RecordId): "photo" | "text" =>
  store.find(mealId)?.sentTextId === undefined ? "photo" : "text";
