import { describe, expect, test } from "vitest";
import { computeMaintenancePlan } from "./index";

describe("維持の目標", () => {
  describe("開始の日の体重の傾向が 0.1kg の倍数でないとき", () => {
    test("0.1kg 単位に丸めた体重の傾向を目標体重に、推定消費カロリーを1日の目安にすること", () => {
      // P は 65.0 × 1.6 で 104g、F は 562.5 kcal ÷ 9 で 62.5g、C は（2,250 − 105×4 − 65×9）÷ 4 で 311.25g
      expect(
        computeMaintenancePlan({ expenditureKcal: 2253, startingWeightTrendKg: 64.96 }),
      ).toEqual({
        targetWeightKg: 65,
        dailyGuide: {
          energyKcal: 2250,
          proteinG: 105,
          fatG: 65,
          carbohydrateG: 310,
          limitHits: [],
        },
      });
    });
  });
});
