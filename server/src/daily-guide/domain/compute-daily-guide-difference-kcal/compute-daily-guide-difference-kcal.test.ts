import { describe, expect, test } from "vitest";
import { computeDailyGuideDifferenceKcal } from "./index";

describe("1日の目安と推定消費カロリーの差", () => {
  describe("1日の目安が推定消費カロリーより少ないとき", () => {
    test("差を 50 kcal 単位に丸め、負の値で返すこと", () => {
      expect(
        computeDailyGuideDifferenceKcal({ expenditureKcal: 2253, dailyGuideEnergyKcal: 1850 }),
      ).toBe(-400);
    });
  });

  describe("1日の目安が推定消費カロリーより多いとき", () => {
    test("差を 50 kcal 単位に丸め、正の値で返すこと", () => {
      expect(
        computeDailyGuideDifferenceKcal({ expenditureKcal: 2018, dailyGuideEnergyKcal: 2350 }),
      ).toBe(350);
    });
  });

  describe("差が 25 kcal に満たないとき", () => {
    test("0 を返すこと", () => {
      expect(
        computeDailyGuideDifferenceKcal({ expenditureKcal: 2260, dailyGuideEnergyKcal: 2250 }),
      ).toBe(0);
    });
  });
});
