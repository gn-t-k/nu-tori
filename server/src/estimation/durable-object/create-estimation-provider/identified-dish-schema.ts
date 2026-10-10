import { z } from "zod";
import nutrients from "../../../../../shared/nutrients.json";

const nutrientNames = Object.keys(nutrients);

// 料理の形。文章の食事の ① も同じ形で料理を返させる
export const identifiedDishSchema = z.object({
  name: z.string(),
  quantity: z.number(),
  unit: z.string(),
  ingredients: z.array(
    z.object({
      name: z.string(),
      quantity: z.number(),
      unit: z.string(),
      edibleGramsPerUnit: z.number(),
      foodCompositionQuery: z.string(),
      nutritionLabel: z
        .object({
          basisGrams: z.number(),
          // 栄養の名前をキーにした表は構造化出力で書けないので、名前と値の組の並びにする
          nutrients: z.array(z.object({ nutrient: z.enum(nutrientNames), amount: z.number() })),
        })
        .nullable(),
    }),
  ),
});
