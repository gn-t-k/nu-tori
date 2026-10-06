import type { Dish } from "../../dish/domain/dish";
import type { Ingredient } from "../../ingredient/domain/ingredient";

// 確かめに通った推定の結果の料理。ID と並び順は書くときに付ける（並び順は並びの順）
export type EstimatedDish = Pick<Dish, "name" | "quantity" | "unit"> & {
  ingredients: readonly Omit<Ingredient, "id" | "dishId" | "estimationId" | "positionInDish">[];
};
