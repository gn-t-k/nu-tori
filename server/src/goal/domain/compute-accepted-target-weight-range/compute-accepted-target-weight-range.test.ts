import { describe, expect, test } from "vitest";
import { computeAcceptedTargetWeightRange } from "./index";

describe("自分で決める目標体重の受け付ける幅", () => {
  describe("減量で、ハード案の速さでも1日の目安が 1,200 kcal を下回らないとき", () => {
    test("下の端をハード案の目標体重、上の端を体重の傾向の 0.1kg 下にすること", () => {
      // 72.4 kg × (1 − 0.75% × 12 週) は 65.884 kg
      expect(
        computeAcceptedTargetWeightRange({
          direction: "lose",
          expenditureKcal: 2250,
          startingWeightTrendKg: 72.4,
          daysFromStartToDeadline: 84,
        }),
      ).toEqual({ minimumKg: 65.9, maximumKg: 72.3, fastestEndReason: "pace_too_fast" });
    });
  });

  describe("減量で、ハード案の速さだと1日の目安が 1,200 kcal を下回るとき", () => {
    test("下の端を、1日の目安が 1,200 kcal を下回らない目標体重にすること", () => {
      // 1日に 300 kcal まで減らせて、84 日で 3.27 kg。60 − 3.27 は 56.73 kg
      expect(
        computeAcceptedTargetWeightRange({
          direction: "lose",
          expenditureKcal: 1500,
          startingWeightTrendKg: 60,
          daysFromStartToDeadline: 84,
        }),
      ).toEqual({
        minimumKg: 56.8,
        maximumKg: 59.9,
        fastestEndReason: "daily_guide_below_minimum",
      });
    });
  });

  describe("減量で、体重の傾向が 0.1kg の倍数でないとき", () => {
    test("上の端を、0.1kg に丸めた体重の傾向の 0.1kg 下にすること", () => {
      expect(
        computeAcceptedTargetWeightRange({
          direction: "lose",
          expenditureKcal: 2250,
          startingWeightTrendKg: 72.43,
          daysFromStartToDeadline: 84,
        })?.maximumKg,
      ).toBe(72.3);
    });
  });

  describe("減量で、推定消費カロリーが 1,200 kcal のとき", () => {
    test("幅が無いこと", () => {
      expect(
        computeAcceptedTargetWeightRange({
          direction: "lose",
          expenditureKcal: 1200,
          startingWeightTrendKg: 60,
          daysFromStartToDeadline: 84,
        }),
      ).toBeUndefined();
    });
  });

  describe("増量のとき", () => {
    test("下の端を体重の傾向の 0.1kg 上、上の端をハード案の目標体重にすること", () => {
      // 60 kg × (1 + 0.5% × 8 週) は 62.4 kg
      expect(
        computeAcceptedTargetWeightRange({
          direction: "gain",
          expenditureKcal: 2000,
          startingWeightTrendKg: 60,
          daysFromStartToDeadline: 56,
        }),
      ).toEqual({ minimumKg: 60.1, maximumKg: 62.4, fastestEndReason: "pace_too_fast" });
    });
  });

  describe("増量で、推定消費カロリーが 1,200 kcal を下回るとき", () => {
    test("下限で幅を狭めないこと", () => {
      expect(
        computeAcceptedTargetWeightRange({
          direction: "gain",
          expenditureKcal: 1000,
          startingWeightTrendKg: 60,
          daysFromStartToDeadline: 56,
        }),
      ).toEqual({ minimumKg: 60.1, maximumKg: 62.4, fastestEndReason: "pace_too_fast" });
    });
  });
});
