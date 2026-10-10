import type { NutrientName } from "../../../domain/food-composition/nutrient-name";
import type { Ingredient } from "../ingredient";
import type { NutrientAmount } from "../nutrient-amount";

// 材料の栄養 = 値 × 量 × 1単位あたりの可食部の g ÷ 基準の g。kcal も材料の kcal の和で、P・F・C から出し直さない（ADR-0016）。
// 端末の NutrientTotals と同じ決めごとで、入力と期待値は shared/nutrient-totals.test-cases.json
export const computeNutrientTotal = (
  ingredients: readonly Pick<
    Ingredient,
    "quantity" | "edibleGramsPerUnit" | "nutrientSource" | "nutrients"
  >[],
  nutrient: NutrientName,
): NutrientAmount => {
  let sum = 0;
  let hasKnown = false;
  let hasUnknown = false;
  for (const ingredient of ingredients) {
    const value = ingredient.nutrients[nutrient];
    if (value === undefined) {
      hasUnknown = true;
    } else {
      sum += (value * ingredient.quantity * ingredient.edibleGramsPerUnit) / basisGrams(ingredient);
      hasKnown = true;
    }
  }
  if (!hasUnknown) {
    return { type: "exactly", value: sum };
  }
  return hasKnown ? { type: "at_least", value: sum } : { type: "unknown" };
};

const basisGrams = ({ nutrientSource }: Pick<Ingredient, "nutrientSource">): number =>
  nutrientSource.type === "nutrition_label" ? nutrientSource.labelBasisGrams : 100;
