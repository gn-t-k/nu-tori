import { describe, expect, test } from "vitest";
import { computeDailyGuideEnergy } from "./index";

describe("1日の目安のカロリー", () => {
  describe("減量のとき", () => {
    describe("必要な速さがハード案の速さより遅いとき", () => {
      test("推定消費カロリーから、必要な速さの分を引いて 50 kcal 単位に丸めること", () => {
        // 必要な速さは 4.3 kg ÷ 84 日。7,700 kcal を掛けると 1日に 394.2 kcal
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 2250,
            goal: {
              direction: "lose",
              startingWeightTrendKg: 72.4,
              targetWeightKg: 68.1,
              daysFromStartToDeadline: 84,
            },
          }),
        ).toEqual({ energyKcal: 1850, limitHits: [] });
      });
    });

    describe("期限まで7日に満たないとき", () => {
      test("必要な速さを7日で割って出すこと", () => {
        // 0.1 kg ÷ 7 日で 1日に 110 kcal。3日で割ると 256.7 kcal になり、1,750 kcal になる
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 2000,
            goal: {
              direction: "lose",
              startingWeightTrendKg: 70,
              targetWeightKg: 69.9,
              daysFromStartToDeadline: 3,
            },
          }),
        ).toEqual({ energyKcal: 1900, limitHits: [] });
      });
    });

    describe("目標体重が開始の日の体重の傾向より重いとき", () => {
      test("推定消費カロリーより多くしないこと", () => {
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 2000,
            goal: {
              direction: "lose",
              startingWeightTrendKg: 70,
              targetWeightKg: 71,
              daysFromStartToDeadline: 28,
            },
          }),
        ).toEqual({ energyKcal: 2000, limitHits: [] });
      });
    });

    describe("必要な速さがハード案の速さを超えるとき", () => {
      test("ハード案の速さで止め、必要な速さの上限に当たったと返すこと", () => {
        // 上限は 70 kg × 0.75% ÷ 7 日で、1日に 577.5 kcal
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 2000,
            goal: {
              direction: "lose",
              startingWeightTrendKg: 70,
              targetWeightKg: 60,
              daysFromStartToDeadline: 28,
            },
          }),
        ).toEqual({ energyKcal: 1400, limitHits: ["required_pace"] });
      });

      test("推定消費カロリーから 150 kcal より大きく離れても、そのまま返すこと", () => {
        const { energyKcal } = computeDailyGuideEnergy({
          expenditureKcal: 2000,
          goal: {
            direction: "lose",
            startingWeightTrendKg: 70,
            targetWeightKg: 60,
            daysFromStartToDeadline: 28,
          },
        });

        expect(2000 - energyKcal).toBe(600);
      });
    });

    describe("1,200 kcal を下回るとき", () => {
      test("1,200 kcal にして、下限に当たったと返すこと", () => {
        // 2 kg ÷ 28 日で 1日に 550 kcal。1,700 kcal から引くと 1,150 kcal
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 1700,
            goal: {
              direction: "lose",
              startingWeightTrendKg: 70,
              targetWeightKg: 68,
              daysFromStartToDeadline: 28,
            },
          }),
        ).toEqual({ energyKcal: 1200, limitHits: ["minimum_energy"] });
      });
    });

    describe("必要な速さの上限で止めても 1,200 kcal を下回るとき", () => {
      test("当たった上限と下限の両方を返すこと", () => {
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 1700,
            goal: {
              direction: "lose",
              startingWeightTrendKg: 70,
              targetWeightKg: 60,
              daysFromStartToDeadline: 28,
            },
          }),
        ).toEqual({ energyKcal: 1200, limitHits: ["required_pace", "minimum_energy"] });
      });
    });

    describe("丸める前が 1,200 kcal より上で、丸めると 1,200 kcal になるとき", () => {
      test("下限に当たったと返さないこと", () => {
        // 3.2 kg ÷ 84 日で 1日に 293.3 kcal。1,500 kcal から引くと 1,206.7 kcal
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 1500,
            goal: {
              direction: "lose",
              startingWeightTrendKg: 60,
              targetWeightKg: 56.8,
              daysFromStartToDeadline: 84,
            },
          }),
        ).toEqual({ energyKcal: 1200, limitHits: [] });
      });
    });
  });

  describe("増量のとき", () => {
    describe("必要な速さがハード案の速さちょうどのとき", () => {
      test("推定消費カロリーに必要な速さの分を足し、上限に当たったと返さないこと", () => {
        // 2.4 kg ÷ 56 日は、上限の 60 kg × 0.5% ÷ 7 日と同じで、1日に 330 kcal
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 2000,
            goal: {
              direction: "gain",
              startingWeightTrendKg: 60,
              targetWeightKg: 62.4,
              daysFromStartToDeadline: 56,
            },
          }),
        ).toEqual({ energyKcal: 2350, limitHits: [] });
      });
    });

    describe("目標体重が開始の日の体重の傾向より軽いとき", () => {
      test("推定消費カロリーより少なくしないこと", () => {
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 2000,
            goal: {
              direction: "gain",
              startingWeightTrendKg: 60,
              targetWeightKg: 59,
              daysFromStartToDeadline: 56,
            },
          }),
        ).toEqual({ energyKcal: 2000, limitHits: [] });
      });
    });

    describe("必要な速さがハード案の速さを超えるとき", () => {
      test("ハード案の速さで止め、必要な速さの上限に当たったと返すこと", () => {
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 2000,
            goal: {
              direction: "gain",
              startingWeightTrendKg: 60,
              targetWeightKg: 65,
              daysFromStartToDeadline: 56,
            },
          }),
        ).toEqual({ energyKcal: 2350, limitHits: ["required_pace"] });
      });
    });
  });

  describe("維持のとき", () => {
    describe("推定消費カロリーが 50 kcal の倍数の真ん中のとき", () => {
      test("推定消費カロリーを、50 kcal 単位に切り上げること", () => {
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 2225,
            goal: { direction: "maintain", targetWeightKg: 65 },
          }),
        ).toEqual({ energyKcal: 2250, limitHits: [] });
      });
    });

    describe("推定消費カロリーが 50 kcal の倍数の真ん中より少ないとき", () => {
      test("推定消費カロリーを、50 kcal 単位に切り下げること", () => {
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 2224,
            goal: { direction: "maintain", targetWeightKg: 65 },
          }),
        ).toEqual({ energyKcal: 2200, limitHits: [] });
      });
    });

    describe("推定消費カロリーが 1,200 kcal を下回るとき", () => {
      test("1,200 kcal にして、下限に当たったと返すこと", () => {
        expect(
          computeDailyGuideEnergy({
            expenditureKcal: 1100,
            goal: { direction: "maintain", targetWeightKg: 40 },
          }),
        ).toEqual({ energyKcal: 1200, limitHits: ["minimum_energy"] });
      });
    });
  });
});
