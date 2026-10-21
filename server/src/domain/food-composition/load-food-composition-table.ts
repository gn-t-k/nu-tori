import { z } from "zod";
import type { FoodCompositionEntry } from "./food-composition-entry";
import tableFile from "./food-composition-table.json";
import type { NutrientName } from "./nutrient-name";
import { isNutrientName } from "./nutrient-name";

// 同梱の成分表のデータファイル（server/scripts/build-food-composition-table.ts が成分表の Excel から作る）を読む。出典はファイルの source
// 栄養の項目の名前が shared/nutrients.json に無いなど、形が合わなければ投げる
// 読むのに 60 ms ほどかかる。Worker の起動で払わないよう、使うときに呼ぶ
export const loadFoodCompositionTable = (): readonly FoodCompositionEntry[] =>
  z
    .object({
      foods: z.array(
        z.object({
          foodNumber: z.string(),
          name: z.string(),
          aliases: z.array(z.string()),
          nutrients: z.record(z.string(), z.number()).transform((values, context) => {
            const nutrients: Partial<Record<NutrientName, number>> = {};
            for (const [name, value] of Object.entries(values)) {
              if (isNutrientName(name)) {
                nutrients[name] = value;
              } else {
                context.addIssue({ code: "custom", message: `栄養の項目にない名前: ${name}` });
              }
            }
            return nutrients;
          }),
        }),
      ),
    })
    .parse(tableFile).foods;
