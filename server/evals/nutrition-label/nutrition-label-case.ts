import { match } from "ts-pattern";
import { z } from "zod";
import type { IdentificationTarget } from "../../src/estimation/domain/estimation-provider";

// 表示の読み取りの評価のケースの正解（expected.json）の形。R2 の nu-tori-evals の nutrition-label/<番号>-<名前>/ に、写真（photo-1.jpg、photo-2.jpg …）と並べて置く。
// 例（ご飯にレトルトカレーと箱。推定し直しのケースは target を { "type": "dish", "name": "カレーライス" } にする）:
// { "target": { "type": "meal" },
//   "expected": { "type": "labeled", "dishes": [ { "nameIncludes": ["カレー"], "ingredients": [
//     { "source": "food_composition" },
//     { "source": "nutrition_label", "nutrients": { "energy_kcal": 200, "protein_g": 5.1, "fat_g": 9.8, "carbohydrate_g": 23, "salt_equivalent_g": 2.4 } } ] } ] } }
// 表示が写っていないケースは "expected": { "type": "no_label" }
export type NutritionLabelCase = z.infer<typeof nutritionLabelCaseSchema>;

// 比べる栄養。表示に書かれていない栄養は正解に書かず、答えも「不明」であることを求める
export const comparedNutrients = [
  "energy_kcal",
  "protein_g",
  "fat_g",
  "carbohydrate_g",
  "salt_equivalent_g",
] as const;

const expectedIngredientSchema = z.discriminatedUnion("source", [
  // 表示の材料。値は全部食べた前提の、その材料の量ぜんぶの値（「1食あたり」なら表示の値そのもの）
  z.object({
    source: z.literal("nutrition_label"),
    nutrients: z.partialRecord(z.enum(comparedNutrients), z.number().nonnegative()),
  }),
  // 表示を付けず、成分表を引く材料（② は呼ばないので、成分表か AI の推定かは見分けない）
  z.object({ source: z.literal("food_composition") }),
]);

export const nutritionLabelCaseSchema = z.object({
  // 写真の推定は meal。推定し直しは、直したあとの料理の名前を渡す
  target: z.discriminatedUnion("type", [
    z.object({ type: z.literal("meal") }),
    z.object({ type: z.literal("dish"), name: z.string().min(1) }),
  ]),
  expected: z.discriminatedUnion("type", [
    // 期待する料理の並び（順は問わない）。料理ごとの材料は、表示の材料どうしを並びの順で比べ、成分表の材料は数だけを比べる
    z.object({
      type: z.literal("labeled"),
      dishes: z
        .array(
          z.object({
            // 料理の名前に、どれかが入っていれば通す（商品名、欄が分かれた表示は欄の名前）。空なら名前を見ない
            nameIncludes: z.array(z.string().min(1)),
            ingredients: z.array(expectedIngredientSchema).min(1),
          }),
        )
        .min(1),
    }),
    // 表示が写っていない。表示の材料が1つも無いことを求める
    z.object({ type: z.literal("no_label") }),
  ]),
});

// 推定し直しは、料理を足したときと同じく、直した材料と量の無い料理として渡す
export const toIdentificationTarget = (
  target: NutritionLabelCase["target"],
): IdentificationTarget =>
  match(target)
    .with({ type: "meal" }, (): IdentificationTarget => ({ type: "meal" }))
    .with({ type: "dish" }, ({ name }): IdentificationTarget => ({
      type: "dish",
      dish: { name, correctedIngredients: [], correctedQuantity: undefined },
    }))
    .exhaustive();
