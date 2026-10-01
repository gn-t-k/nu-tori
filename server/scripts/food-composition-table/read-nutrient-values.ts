import type { NutrientName } from "../../src/domain/food-composition/nutrient-name";
import { isNutrientName } from "../../src/domain/food-composition/nutrient-name";
import { nutrientSourceColumns } from "../../src/domain/food-composition/nutrient-source-columns";
import { readComponentValue } from "./read-component-value";

// 成分識別子 → セルの値 から、栄養の項目ごとの値を読む。不明（どの列も「-」）の項目は持たない
export const readNutrientValues = (
  components: Readonly<Record<string, unknown>>,
): Partial<Record<NutrientName, number>> => {
  const values: Partial<Record<NutrientName, number>> = {};
  for (const [nutrient, columns] of Object.entries(nutrientSourceColumns)) {
    if (!isNutrientName(nutrient)) {
      throw new Error(`栄養の項目でない名前: ${nutrient}`);
    }
    for (const column of columns) {
      const value = readComponentValue(components[column]);
      if (value !== undefined) {
        values[nutrient] = value;
        break;
      }
    }
  }
  return values;
};
