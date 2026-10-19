import { beforeEach, describe, expect, test } from "vitest";
import { computeReviewedDailyGuide } from "./index";

type Input = Parameters<typeof computeReviewedDailyGuide>[0];

// 減量の目標。見直す月曜から期限の日まで 56 日、日曜の体重の傾向から目標体重まで 4 kg で、
// 必要な速さの分は 4 kg ÷ 56 日 × 7,700 kcal = 1日に 550 kcal。
// ハード案の速さの上限は 72.4 kg × 0.75% ÷ 7 日 × 7,700 kcal = 1日に 597.3 kcal で、当たらない
const losingGoal = {
  direction: "lose",
  goalStartingWeightTrendKg: 72.4,
  targetWeightKg: 68,
  weightTrendKg: 72,
  daysToDeadline: 56,
} as const;

describe("見直した1日の目安", () => {
  let input: Input;

  describe("維持の目標で、推定消費カロリーが 300 kcal 上がったとき", () => {
    beforeEach(() => {
      input = {
        expenditureKcal: 2700,
        previous: { energyKcal: 2400, expenditureKcal: 2400 },
        goal: { direction: "maintain", targetWeightKg: 70, weightTrendKg: 70 },
      };
    });

    test("前の週から +150 kcal で止め、1週の変化に当たったと返すこと", () => {
      expect(computeReviewedDailyGuide(input)).toEqual({
        energyKcal: 2550,
        proteinG: 110,
        fatG: 70,
        carbohydrateG: 370,
        limitHits: ["weekly_change"],
        mainReason: "expenditure_change",
      });
    });
  });

  describe("維持の目標で、推定消費カロリーが 400 kcal 下がったとき", () => {
    beforeEach(() => {
      input = {
        expenditureKcal: 2000,
        previous: { energyKcal: 2400, expenditureKcal: 2400 },
        goal: { direction: "maintain", targetWeightKg: 70, weightTrendKg: 70 },
      };
    });

    test("前の週から −150 kcal で止めること", () => {
      expect(computeReviewedDailyGuide(input)).toMatchObject({
        energyKcal: 2250,
        limitHits: ["weekly_change"],
      });
    });
  });

  describe("維持の目標で、体重の傾向が目標体重から 0.7 kg 離れているとき", () => {
    beforeEach(() => {
      input = {
        expenditureKcal: 2400,
        previous: { energyKcal: 2400, expenditureKcal: 2400 },
        goal: { direction: "maintain", targetWeightKg: 70, weightTrendKg: 70.7 },
      };
    });

    test("幅の中として、推定消費カロリーのままにすること", () => {
      expect(computeReviewedDailyGuide(input)).toMatchObject({ energyKcal: 2400, limitHits: [] });
    });
  });

  describe("維持の目標で、体重の傾向が目標体重より 1 kg 重いとき", () => {
    beforeEach(() => {
      // 71 kg × 0.15% ÷ 7 日 × 7,700 kcal = 1日に 117.2 kcal
      input = {
        expenditureKcal: 2400,
        previous: { energyKcal: 2400, expenditureKcal: 2400 },
        goal: { direction: "maintain", targetWeightKg: 70, weightTrendKg: 71 },
      };
    });

    test("体重の傾向の 0.15%/週の速さで目標体重へ戻す分を引くこと", () => {
      expect(computeReviewedDailyGuide(input)).toMatchObject({
        energyKcal: 2300,
        limitHits: [],
        mainReason: "balance_change",
      });
    });
  });

  describe("減量の目標で、日曜の体重の傾向と見直す月曜から期限の日までの日数で必要な速さを出すとき", () => {
    beforeEach(() => {
      input = {
        expenditureKcal: 2400,
        previous: { energyKcal: 1900, expenditureKcal: 2400 },
        goal: losingGoal,
      };
    });

    test("新しい推定消費カロリーから、必要な速さの分を引くこと", () => {
      expect(computeReviewedDailyGuide(input)).toMatchObject({
        energyKcal: 1850,
        limitHits: [],
        mainReason: "balance_change",
      });
    });
  });

  describe("減量の目標で、必要な速さが目標の開始の日の体重の傾向から出したハード案の速さを超えるとき", () => {
    beforeEach(() => {
      // 12 kg ÷ 28 日は上限を超え、1日に 597.3 kcal で止める
      input = {
        expenditureKcal: 2400,
        previous: { energyKcal: 1800, expenditureKcal: 2400 },
        goal: { ...losingGoal, targetWeightKg: 60, daysToDeadline: 28 },
      };
    });

    test("ハード案の速さで止め、必要な速さの上限に当たったと返すこと", () => {
      expect(computeReviewedDailyGuide(input)).toMatchObject({
        energyKcal: 1800,
        limitHits: ["required_pace"],
      });
    });
  });

  describe("減量の目標で、1,200 kcal を下回るとき", () => {
    beforeEach(() => {
      input = {
        expenditureKcal: 1600,
        previous: { energyKcal: 1250, expenditureKcal: 1700 },
        goal: losingGoal,
      };
    });

    test("1,200 kcal にして、下限に当たったと返すこと", () => {
      expect(computeReviewedDailyGuide(input)).toMatchObject({
        energyKcal: 1200,
        limitHits: ["minimum_energy"],
      });
    });
  });

  describe("達成したあと、体重の傾向が目標体重を越えたとき", () => {
    beforeEach(() => {
      // 必要な速さは向きと逆にしないので 0。2,400 kcal に向かうところを、1,900 kcal から +150 kcal で止める
      input = {
        expenditureKcal: 2400,
        previous: { energyKcal: 1900, expenditureKcal: 2400 },
        goal: { ...losingGoal, weightTrendKg: 67.8 },
      };
    });

    test("1日に減らす分を 0 に向けて、前の週から +150 kcal まで戻すこと", () => {
      expect(computeReviewedDailyGuide(input)).toMatchObject({
        energyKcal: 2050,
        limitHits: ["weekly_change"],
        mainReason: "balance_change",
      });
    });
  });

  describe("主な理由", () => {
    describe("推定消費カロリーの変化と、1日に減らす分の変化が同じとき", () => {
      beforeEach(() => {
        // 推定消費カロリーは +50 kcal、減らす分は 600 kcal から 550 kcal で +50 kcal
        input = {
          expenditureKcal: 2450,
          previous: { energyKcal: 1800, expenditureKcal: 2400 },
          goal: losingGoal,
        };
      });

      test("推定消費カロリーの変化にすること", () => {
        expect(computeReviewedDailyGuide(input)).toMatchObject({
          energyKcal: 1900,
          mainReason: "expenditure_change",
        });
      });
    });

    describe("50 kcal に丸めたあとの値で分けると、大きいほうが入れ替わるとき", () => {
      beforeEach(() => {
        // 減らす分は 5.6 kg ÷ 77 日 × 7,700 kcal = 560 kcal。丸める前は 1,885 kcal で、
        // 推定消費カロリーの変化 +45 kcal、減らす分の変化 +40 kcal。丸めた 1,900 kcal では減らす分の変化が +55 kcal になる
        input = {
          expenditureKcal: 2445,
          previous: { energyKcal: 1800, expenditureKcal: 2400 },
          goal: {
            direction: "lose",
            goalStartingWeightTrendKg: 76,
            targetWeightKg: 70,
            weightTrendKg: 75.6,
            daysToDeadline: 77,
          },
        };
      });

      test("丸める前の値で分けること", () => {
        expect(computeReviewedDailyGuide(input)).toMatchObject({
          energyKcal: 1900,
          mainReason: "expenditure_change",
        });
      });
    });
  });
});
