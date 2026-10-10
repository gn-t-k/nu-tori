import { describe, expect, test } from "vitest";
import testCases from "../../../../../shared/nutrient-totals.test-cases.json";
import { isNutrientName } from "../../../domain/food-composition/nutrient-name";
import type { IngredientNutrientSource } from "../ingredient";
import { computeNutrientTotal } from "./index";

describe("栄養の合計", () => {
  test.for(testCases)(
    "$name とき、値の分かる材料の分を足し、不明が混じれば以上、すべて不明なら不明になること",
    ({ ingredients, totals }) => {
      const parsedIngredients = ingredients.map((ingredient) => ({
        ...ingredient,
        nutrientSource: toNutrientSource(ingredient.nutrientSource),
      }));

      for (const [name, expected] of Object.entries(totals)) {
        if (!isNutrientName(name)) {
          throw new Error(`知らない栄養の名前: ${name}`);
        }
        expect(computeNutrientTotal(parsedIngredients, name)).toEqual(expected);
      }
    },
  );
});

const toNutrientSource = (source: {
  type: string;
  labelBasisGrams?: number;
  foodNumber?: string;
}): IngredientNutrientSource => {
  if (source.type === "nutrition_label" && source.labelBasisGrams !== undefined) {
    return { type: "nutrition_label", labelBasisGrams: source.labelBasisGrams };
  }
  if (source.type === "food_composition" && source.foodNumber !== undefined) {
    return { type: "food_composition", foodNumber: source.foodNumber };
  }
  if (source.type === "estimated") {
    return { type: "estimated" };
  }
  throw new Error(`読めない出どころ: ${source.type}`);
};
