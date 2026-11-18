import { match } from "ts-pattern";
import nutrientDefinitions from "../../../../shared/nutrients.json";
import { isNutrientName } from "../../domain/food-composition/nutrient-name";
import type { NutrientName } from "../../domain/food-composition/nutrient-name";

// 基準の読み違い（1袋あたりの値を 1 g あたりと読む、1食分の値を 100 g あたりとして答える）で桁が跳ねた答えを落とす
export const isPossibleInFood = (
  nutrient: NutrientName,
  amount: number,
  basisGrams: number,
): boolean => {
  // 正しい記録をはじかない高さに置く。純粋な脂質で 100 g あたり約 900 kcal で、栄養成分表示の許容差（±20%）を見込む
  const maximumEnergyKcalPer100Grams = 1200;
  // 重さより多くは入らない（100 g）が、① は ml を g とみなすので、水あめのように重い液体の表示は 100 ml あたり 120 g 近くになる。それが通るよう、重さの倍に置く
  const maximumGramsPer100Grams = 200;
  const amountPer100Grams = (amount / basisGrams) * 100;
  return (
    match(nutrientUnit(nutrient))
      .with("kcal", () => amountPer100Grams <= maximumEnergyKcalPer100Grams)
      .with("g", () => amountPer100Grams <= maximumGramsPer100Grams)
      // mg・µg の項目には、ありえないと言える上限が無いので確かめない
      .with("mg", "µg", () => true)
      .exhaustive()
  );
};

// JSON の import では単位の型が string になるので、知っている単位に絞る
const nutrientUnit = (nutrient: NutrientName): NutrientUnit => {
  const { unit } = nutrientDefinitions[nutrient];
  if (!isNutrientUnit(unit)) {
    throw new Error(`shared/nutrients.json の ${nutrient} の単位「${unit}」を知らない`);
  }
  return unit;
};

const nutrientUnits = ["kcal", "g", "mg", "µg"] as const;

type NutrientUnit = (typeof nutrientUnits)[number];

const isNutrientUnit = (value: string): value is NutrientUnit =>
  nutrientUnits.some((unit) => unit === value);

// 知らない単位を、推定の答えに出たときでなく、読み込んだときに落とす。このモジュールを読み込むテストが落ちて気づける
for (const nutrient of Object.keys(nutrientDefinitions).filter(isNutrientName)) {
  nutrientUnit(nutrient);
}
