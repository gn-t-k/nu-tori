import { isNutrientName } from "../../domain/food-composition/nutrient-name";
import type { EstimatedDish } from "./estimated-dish";
import type { IdentifiedIngredient } from "./estimation-provider";

// 栄養成分表示の付いた ① の材料を、記録する材料の形にする。推定の試みと、表示の読み取りの評価（evals/nutrition-label）が同じ形を使う
export const composeLabeledIngredient = (
  ingredient: IdentifiedIngredient,
  nutritionLabel: NonNullable<IdentifiedIngredient["nutritionLabel"]>,
): EstimatedDish["ingredients"][number] => ({
  name: ingredient.name,
  quantity: ingredient.quantity,
  unit: ingredient.unit,
  // 栄養に使う g は ① が直接見積もった合計で、量と掛け合わせて作らない（量と1単位あたりを別々に答えさせると、重ねて答えたときに桁が跳ねる）
  edibleGramsPerUnit: ingredient.edibleGrams / ingredient.quantity,
  nutrientSource: { type: "nutrition_label", labelBasisGrams: nutritionLabel.basisGrams },
  nutrients: Object.fromEntries(
    Object.entries(nutritionLabel.nutrients).filter(([nutrient]) => isNutrientName(nutrient)),
  ),
});
