import { describe, expect, test } from "vitest";
import { computeMacronutrientGuides } from "./index";

describe("P・F・C の目安", () => {
  describe("P の kcal が1日の目安の 35% に収まるとき", () => {
    test("P を目標体重 1kg あたり 1.6g、F を1日の目安の 25%、C を残りから出し、5g 単位に丸めること", () => {
      // P は 108.96g、F は 462.5 kcal ÷ 9 で 51.4g、C は（1,850 − 110×4 − 50×9）÷ 4 で 240g
      expect(computeMacronutrientGuides({ energyKcal: 1850, targetWeightKg: 68.1 })).toEqual({
        proteinG: 110,
        fatG: 50,
        carbohydrateG: 240,
      });
    });
  });

  describe("C の残りが 5g の倍数でないとき", () => {
    test("C を、丸めた P と F を引いた残りから出して 5g 単位に丸めること", () => {
      // P は 112.48g、F は 56.9g、C は（2,050 − 110×4 − 55×9）÷ 4 で 278.75g
      expect(computeMacronutrientGuides({ energyKcal: 2050, targetWeightKg: 70.3 })).toEqual({
        proteinG: 110,
        fatG: 55,
        carbohydrateG: 280,
      });
    });
  });

  describe("P の kcal が1日の目安の 35% を超えるとき", () => {
    test("P を1日の目安の 35% にすること", () => {
      // 目標体重からは 128g。35% は 420 kcal で 105g
      expect(computeMacronutrientGuides({ energyKcal: 1200, targetWeightKg: 80 })).toEqual({
        proteinG: 105,
        fatG: 35,
        carbohydrateG: 115,
      });
    });
  });

  describe("1日の目安の 35% が 5g の倍数でないとき", () => {
    test("P を 35% を超えない 5g 単位にすること", () => {
      // 35% は 437.5 kcal で 109.4g
      expect(computeMacronutrientGuides({ energyKcal: 1250, targetWeightKg: 80 })).toEqual({
        proteinG: 105,
        fatG: 35,
        carbohydrateG: 130,
      });
    });
  });
});
