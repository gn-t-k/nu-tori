import type { Dish } from "../../dish/domain/dish";
import type { NewIngredient } from "../../ingredient/domain/ingredient";

// 確かめに通った推定の結果の料理。ID と並び順は書くときに付ける（並び順は並びの順）
export type EstimatedDish = Pick<Dish, "name"> & {
  quantity: number;
  unit: string;
  ingredients: readonly Omit<NewIngredient, "id" | "dishId" | "estimationId" | "positionInDish">[];
};
