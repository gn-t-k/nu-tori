import { describe, expect, test } from "vitest";
import { listReferableMealIds } from "../../src/reply/domain/list-referable-meal-ids";
import { replyEvalCases, type ReplyEvalScene } from "./cases";

// 返事の評価の組（仕様 #419 の「指示と評価」）。場面の数は仕様の 30 場面の内訳
describe("返事の評価の組", () => {
  test("30 場面あること", () => {
    expect(replyEvalCases).toHaveLength(30);
  });

  test("場面の名前が重ならないこと", () => {
    expect(new Set(replyEvalCases.map(({ id }) => id)).size).toBe(replyEvalCases.length);
  });

  test("場面の種類ごとの数が仕様の内訳のとおりであること", () => {
    const counts = Object.fromEntries(
      (
        [
          "preset",
          "below_minimum",
          "medical",
          "eating_disorder",
          "off_topic",
          "correction",
          "unprovided_number",
        ] as const satisfies readonly ReplyEvalScene[]
      ).map((scene) => [scene, replyEvalCases.filter((c) => c.scene === scene).length]),
    );
    expect(counts).toEqual({
      preset: 4,
      below_minimum: 4,
      medical: 4,
      eating_disorder: 4,
      off_topic: 4,
      correction: 5,
      unprovided_number: 5,
    });
  });

  test("プリセットの場面が、2つの文面と記録の多い日・少ない日の組をひとつずつ持つこと", () => {
    const presets = replyEvalCases
      .filter(({ scene }) => scene === "preset")
      .map(({ context, day }) => `${context.newUtterance.body}/${day}`);
    expect(presets.toSorted()).toEqual(
      [
        "ここまでの食事のフィードバックをください。/rich",
        "ここまでの食事のフィードバックをください。/sparse",
        "次の食事のアドバイスをください。/rich",
        "次の食事のアドバイスをください。/sparse",
      ].toSorted(),
    );
  });

  test("いま応える発言が、受け付ける送った文章と同じく、前後の空白を除いて 1〜500 字であること", () => {
    const outOfRange = replyEvalCases.filter(({ context }) => {
      const length = Array.from(context.newUtterance.body.trim()).length;
      return length < 1 || length > 500;
    });
    expect(outOfRange).toEqual([]);
  });

  test("どの場面も、場面に固有の守ることを1つ以上持つこと", () => {
    expect(replyEvalCases.filter(({ rubric }) => rubric.length === 0)).toEqual([]);
  });

  test("記録を直してほしい場面だけが、指し示してほしい食事を持つこと", () => {
    expect(
      replyEvalCases
        .filter(({ expectedMealIds }) => expectedMealIds.length > 0)
        .map(({ scene }) => scene),
    ).toEqual(Array.from({ length: 5 }, () => "correction"));
  });

  test("今日の合計が、今日の料理の栄養を足した値と合うこと", () => {
    const mismatched = replyEvalCases.filter(({ context }) => {
      const todayDishes = context.structuredValues.todayMeals.flatMap(({ dishes }) => dishes);
      const total = context.structuredValues.todayNutrients;
      if (total === undefined) {
        return todayDishes.length > 0;
      }
      return (["energyKcal", "proteinG", "fatG", "carbohydrateG"] as const).some((key) => {
        const amount = total[key];
        const sum = todayDishes.reduce(
          (acc, { nutrients }) =>
            acc + (nutrients[key].type === "exactly" ? nutrients[key].value : Number.NaN),
          0,
        );
        return amount.type !== "exactly" || Math.abs(amount.value - sum) > 1e-9;
      });
    });
    expect(mismatched.map(({ id }) => id)).toEqual([]);
  });

  test("指し示してほしい食事が、文脈で ID を付けた食事であること", () => {
    const unreferable = replyEvalCases.filter(({ context, expectedMealIds }) => {
      const referable = listReferableMealIds(context);
      return expectedMealIds.some((mealId) => !referable.has(mealId));
    });
    expect(unreferable).toEqual([]);
  });
});
