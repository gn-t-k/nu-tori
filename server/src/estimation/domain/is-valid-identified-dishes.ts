import { isNutrientName } from "../../domain/food-composition/nutrient-name";
import type {
  IdentificationTarget,
  IdentifiedDishes,
  IdentifiedIngredient,
} from "./estimation-provider";
import { isPossibleInFood } from "./is-possible-in-food";

// ① の答えを確かめる。推定の試みと、表示の読み取りの評価（evals/nutrition-label）が同じ判定を使い、評価で通って本番で落ちることを防ぐ。
// Claude の構造化出力は数値の範囲を使えないので、量が 0 より大きいことなどをここで確かめる。
// 推定し直しは、その料理1つか、材料を出せない（0 件）の答えだけを通す
export const isValidIdentifiedDishes = (
  { dishes }: IdentifiedDishes,
  target: IdentificationTarget,
): boolean =>
  (target.type === "meal" || dishes.length <= 1) &&
  dishes.every(
    (dish) =>
      isPresentText(dish.name) &&
      isPositive(dish.quantity) &&
      isPresentText(dish.unit) &&
      dish.ingredients.length > 0 &&
      dish.ingredients.every(
        (ingredient) =>
          isPresentText(ingredient.name) &&
          isPositive(ingredient.quantity) &&
          isPresentText(ingredient.unit) &&
          isPositive(ingredient.edibleGrams) &&
          (ingredient.nutritionLabel === undefined ||
            isValidNutritionLabel(ingredient.nutritionLabel)),
      ),
  );

const isValidNutritionLabel = ({
  basisGrams,
  nutrients,
}: NonNullable<IdentifiedIngredient["nutritionLabel"]>): boolean =>
  isPositive(basisGrams) &&
  Object.entries(nutrients).every(
    ([nutrient, amount]) =>
      isNutrientName(nutrient) &&
      isNonNegative(amount) &&
      isPossibleInFood(nutrient, amount, basisGrams),
  );

const isPresentText = (text: string): boolean => text.trim().length > 0;

const isPositive = (value: number): boolean => Number.isFinite(value) && value > 0;

const isNonNegative = (value: number): boolean => Number.isFinite(value) && value >= 0;
