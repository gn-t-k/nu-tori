import { match } from "ts-pattern";
import { composeLabeledIngredient } from "../../../src/estimation/domain/compose-labeled-ingredient";
import type { IdentifiedDishes } from "../../../src/estimation/domain/estimation-provider";
import { isValidIdentifiedDishes } from "../../../src/estimation/domain/is-valid-identified-dishes";
import { computeNutrientTotal } from "../../../src/ingredient/domain/compute-nutrient-total";
import {
  comparedNutrients,
  toIdentificationTarget,
  type NutritionLabelCase,
} from "../nutrition-label-case";

// ① の1回分の答えを、本番の推定の試みと同じ検証と、栄養の合計の数え方（ドメインの正本）に通してから、正解と比べる。
// 式を評価に写さないため、表示の材料の栄養も、記録する材料の形にしてから合計の数え方で出す
export const judgeNutritionLabelRun = (
  answer: IdentifiedDishes,
  { target, expected }: NutritionLabelCase,
): RunVerdict => {
  if (!isValidIdentifiedDishes(answer, toIdentificationTarget(target))) {
    return failed("本番の検証で落ちた");
  }
  return match(expected)
    .with({ type: "no_label" }, () => {
      const labeledCount = answer.dishes
        .flatMap(({ ingredients }) => ingredients)
        .filter(({ nutritionLabel }) => nutritionLabel !== undefined).length;
      return labeledCount === 0 ? passed : failed(`表示の材料が ${labeledCount} 個ある`);
    })
    .with({ type: "labeled" }, ({ dishes: expectedDishes }) => {
      if (answer.dishes.length !== expectedDishes.length) {
        return failed(`料理が ${answer.dishes.length} 個（正解 ${expectedDishes.length} 個）`);
      }
      // 順は問わないので、正解の料理ごとに、まだ当てていない答えの料理から通るものを探す
      const remaining = [...answer.dishes];
      for (const expectedDish of expectedDishes) {
        const found = remaining.findIndex(
          (dish) => judgeDish(dish, expectedDish).type === "passed",
        );
        const [firstRemaining] = remaining;
        if (found === -1) {
          // 落ちた理由は、残った答えの料理の先頭と比べたものを出す（料理の数は同じなので、残りは空でない）
          return firstRemaining === undefined
            ? failed("比べる料理が無い")
            : judgeDish(firstRemaining, expectedDish);
        }
        remaining.splice(found, 1);
      }
      return passed;
    })
    .exhaustive();
};

export type RunVerdict = { type: "passed" } | { type: "failed"; reason: string };

type AnswerDish = IdentifiedDishes["dishes"][number];

type ExpectedDish = Extract<NutritionLabelCase["expected"], { type: "labeled" }>["dishes"][number];

const passed: RunVerdict = { type: "passed" };

const failed = (reason: string): RunVerdict => ({ type: "failed", reason });

const judgeDish = (dish: AnswerDish, expectedDish: ExpectedDish): RunVerdict => {
  const { nameIncludes, ingredients: expectedIngredients } = expectedDish;
  if (nameIncludes.length > 0 && !nameIncludes.some((part) => dish.name.includes(part))) {
    return failed(`料理の名前「${dish.name}」に ${nameIncludes.join("・")} が無い`);
  }
  const labeled = dish.ingredients.flatMap((ingredient) =>
    ingredient.nutritionLabel === undefined
      ? []
      : [composeLabeledIngredient(ingredient, ingredient.nutritionLabel)],
  );
  const unlabeledCount = dish.ingredients.length - labeled.length;
  const expectedLabeled = expectedIngredients.flatMap((ingredient) =>
    ingredient.source === "nutrition_label" ? [ingredient] : [],
  );
  const expectedUnlabeledCount = expectedIngredients.length - expectedLabeled.length;
  if (labeled.length !== expectedLabeled.length || unlabeledCount !== expectedUnlabeledCount) {
    return failed(
      `「${dish.name}」の材料が 表示 ${labeled.length}・成分表 ${unlabeledCount}（正解 表示 ${expectedLabeled.length}・成分表 ${expectedUnlabeledCount}）`,
    );
  }
  for (const [index, ingredient] of labeled.entries()) {
    const expectedNutrients = expectedLabeled[index]?.nutrients ?? {};
    for (const nutrient of comparedNutrients) {
      const total = computeNutrientTotal([ingredient], nutrient);
      const expectedValue = expectedNutrients[nutrient];
      const label = nutrientLabels[nutrient];
      if (expectedValue === undefined) {
        if (total.type !== "unknown") {
          return failed(`「${ingredient.name}」の${label}は表示に無いのに答えた`);
        }
      } else if (total.type !== "exactly") {
        return failed(`「${ingredient.name}」の${label}が不明（表示 ${expectedValue}）`);
      } else if (
        Math.abs(total.value - expectedValue) >
        allowedDifferences[nutrient] + floatSlack
      ) {
        return failed(
          `「${ingredient.name}」の${label} ${formatAmount(total.value)}（表示 ${expectedValue}）`,
        );
      }
    }
  }
  return passed;
};

// 丸めの差（量の掛け割り）を見込む。表示の一番小さい桁に合わせ、kcal・P・F・C は 1、食塩相当量は 0.1 まで。
// 食塩相当量は 2〜6 g と小さく、1 まで許すと「2.4」を「1.4」と読むような読み違いが通るため
const allowedDifferences: Readonly<Record<(typeof comparedNutrients)[number], number>> = {
  energy_kcal: 1,
  protein_g: 1,
  fat_g: 1,
  carbohydrate_g: 1,
  salt_equivalent_g: 0.1,
};

// 表示 6.2・答え 6.1 の差が 0.1 をわずかに超えるような、小数の計算の誤差で落とさない
const floatSlack = 1e-9;

const nutrientLabels: Readonly<Record<(typeof comparedNutrients)[number], string>> = {
  energy_kcal: "エネルギー",
  protein_g: "たんぱく質",
  fat_g: "脂質",
  carbohydrate_g: "炭水化物",
  salt_equivalent_g: "食塩相当量",
};

const formatAmount = (value: number): string => String(Math.round(value * 10) / 10);
