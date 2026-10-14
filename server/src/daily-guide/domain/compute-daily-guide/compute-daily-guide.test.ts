import { describe, expect, test } from "vitest";
import { computeDailyGuide } from "./index";

describe("1日の目安", () => {
  describe("必要な速さの上限に当たる減量のとき", () => {
    test("カロリーと、そのカロリーと目標体重から出した P・F・C の目安と、当たった上限を返すこと", () => {
      // 1,400 kcal の 35% は 122.5g で P は 96g、F は 350 kcal ÷ 9 で 38.9g、C は（1,400 − 95×4 − 40×9）÷ 4 で 165g
      expect(
        computeDailyGuide({
          expenditureKcal: 2000,
          goal: {
            direction: "loss",
            startingWeightTrendKg: 70,
            targetWeightKg: 60,
            daysFromStartToDeadline: 28,
          },
        }),
      ).toEqual({
        energyKcal: 1400,
        proteinG: 95,
        fatG: 40,
        carbohydrateG: 165,
        limitHits: ["required_pace"],
      });
    });
  });
});
