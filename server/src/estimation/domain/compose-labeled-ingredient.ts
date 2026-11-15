import { isNutrientName } from "../../domain/food-composition/nutrient-name";
import { composeIngredientAmount } from "./compose-ingredient-amount";
import type { EstimatedDish } from "./estimated-dish";
import type { IdentifiedIngredient } from "./estimation-provider";

// 栄養成分表示の付いた ① の材料を、記録する材料の形にする。推定の試みと、表示の読み取りの評価（evals/nutrition-label）が同じ形を使う
export const composeLabeledIngredient = (
  ingredient: Omit<IdentifiedIngredient, "nutritionLabel">,
  nutritionLabel: NonNullable<IdentifiedIngredient["nutritionLabel"]>,
): EstimatedDish["ingredients"][number] => ({
  ...composeIngredientAmount(ingredient),
  nutrientSource: { type: "nutrition_label", labelBasisGrams: nutritionLabel.basisGrams },
  nutrients: Object.fromEntries(
    Object.entries(nutritionLabel.nutrients).filter(([nutrient]) => isNutrientName(nutrient)),
  ),
});
