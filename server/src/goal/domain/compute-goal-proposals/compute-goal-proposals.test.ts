import { beforeEach, describe, expect, test } from "vitest";
import { computeGoalProposals } from "./index";

describe("目標案", () => {
  describe("減量のとき", () => {
    describe("どの案も1日の目安が 1,200 kcal を下回らないとき", () => {
      let proposals: ReturnType<typeof computeGoalProposals>["proposals"];
      let hadSlowedProposal: boolean;

      beforeEach(() => {
        ({ proposals, hadSlowedProposal } = computeGoalProposals({
          direction: "lose",
          expenditureKcal: 2250,
          startingWeightTrendKg: 72.4,
          daysFromStartToDeadline: 84,
        }));
      });

      test("ゆるめ・標準・ハードの順に、1週に 0.25%・0.5%・0.75% ずつ減らした目標体重を、0.1kg 単位に切り上げて返すこと", () => {
        // 12 週で 72.4 kg の 97%・94%・91% は、70.228・68.056・65.884 kg
        expect(proposals).toMatchObject([
          { pace: "gentle", status: "offered", targetWeightKg: 70.3 },
          { pace: "standard", status: "offered", targetWeightKg: 68.1 },
          { pace: "hard", status: "offered", targetWeightKg: 65.9 },
        ]);
      });

      test("案ごとに、1日の目安と、推定消費カロリーとの差を返すこと", () => {
        expect(proposals).toMatchObject([
          {
            dailyGuide: { energyKcal: 2050, proteinG: 110, fatG: 55, carbohydrateG: 280 },
            dailyGuideDifferenceKcal: -200,
          },
          {
            dailyGuide: { energyKcal: 1850, proteinG: 110, fatG: 50, carbohydrateG: 240 },
            dailyGuideDifferenceKcal: -400,
          },
          {
            dailyGuide: { energyKcal: 1650, proteinG: 105, fatG: 45, carbohydrateG: 205 },
            dailyGuideDifferenceKcal: -600,
          },
        ]);
      });

      test("速さを落とした案が無いと返すこと", () => {
        expect(hadSlowedProposal).toBe(false);
      });

      test("どの案の1日の目安も、上限にも下限にも当たらないこと", () => {
        expect(proposals).toMatchObject([
          { dailyGuide: { limitHits: [] } },
          { dailyGuide: { limitHits: [] } },
          { dailyGuide: { limitHits: [] } },
        ]);
      });
    });

    describe("標準とハードの案の1日の目安が 1,200 kcal を下回るとき", () => {
      let proposals: ReturnType<typeof computeGoalProposals>["proposals"];
      let hadSlowedProposal: boolean;

      beforeEach(() => {
        // 1日に 300 kcal まで減らせて、84 日で 3.27 kg。標準の速さだと 3.6 kg、ハードだと 5.4 kg
        ({ proposals, hadSlowedProposal } = computeGoalProposals({
          direction: "lose",
          expenditureKcal: 1500,
          startingWeightTrendKg: 60,
          daysFromStartToDeadline: 84,
        }));
      });

      test("速さを落とした案があったと返すこと", () => {
        expect(hadSlowedProposal).toBe(true);
      });

      test("ゆるめの案を、そのままの速さで出すこと", () => {
        expect(proposals[0]).toMatchObject({
          pace: "gentle",
          status: "offered",
          targetWeightKg: 58.2,
          dailyGuide: { energyKcal: 1350, limitHits: [] },
        });
      });

      test("標準の案を、1日の目安が 1,200 kcal を下回らない速さまで落として出すこと", () => {
        expect(proposals[1]).toMatchObject({
          pace: "standard",
          status: "offered",
          targetWeightKg: 56.8,
          dailyGuide: { energyKcal: 1200, limitHits: [] },
          dailyGuideDifferenceKcal: -300,
        });
      });

      test("落とした結果が標準の案と同じ目標体重になるハードの案を、出さないこと", () => {
        expect(proposals[2]).toEqual({
          pace: "hard",
          status: "unavailable",
          reason: "daily_guide_below_minimum",
        });
      });
    });

    describe("どの案の1日の目安も 1,200 kcal を下回るとき", () => {
      let proposals: ReturnType<typeof computeGoalProposals>["proposals"];
      let hadSlowedProposal: boolean;

      beforeEach(() => {
        // 1日に 100 kcal まで減らせて、84 日で 1.09 kg。ゆるめの速さだと 1.8 kg
        ({ proposals, hadSlowedProposal } = computeGoalProposals({
          direction: "lose",
          expenditureKcal: 1300,
          startingWeightTrendKg: 60,
          daysFromStartToDeadline: 84,
        }));
      });

      test("速さを落とした案があったと返すこと", () => {
        expect(hadSlowedProposal).toBe(true);
      });

      test("ゆるめの案だけを、速さを落として出すこと", () => {
        expect(proposals).toMatchObject([
          { pace: "gentle", status: "offered", targetWeightKg: 59 },
          { pace: "standard", status: "unavailable" },
          { pace: "hard", status: "unavailable" },
        ]);
      });
    });

    describe("速さを落とすと、目標体重が 0.1kg の丸めで体重の傾向と同じになるとき", () => {
      let proposals: ReturnType<typeof computeGoalProposals>["proposals"];
      let hadSlowedProposal: boolean;

      beforeEach(() => {
        // 1日に 5 kcal まで減らせて、84 日で 0.05 kg。59.95 kg を切り上げると 60.0 kg
        ({ proposals, hadSlowedProposal } = computeGoalProposals({
          direction: "lose",
          expenditureKcal: 1205,
          startingWeightTrendKg: 60,
          daysFromStartToDeadline: 84,
        }));
      });

      test("速さを落とした案があったと返すこと", () => {
        expect(hadSlowedProposal).toBe(true);
      });

      test("案を1つも出さないこと", () => {
        expect(proposals).toEqual([
          { pace: "gentle", status: "unavailable", reason: "daily_guide_below_minimum" },
          { pace: "standard", status: "unavailable", reason: "daily_guide_below_minimum" },
          { pace: "hard", status: "unavailable", reason: "daily_guide_below_minimum" },
        ]);
      });
    });
  });

  describe("増量のとき", () => {
    describe("推定消費カロリーが 1,200 kcal 以上のとき", () => {
      let proposals: ReturnType<typeof computeGoalProposals>["proposals"];
      let hadSlowedProposal: boolean;

      beforeEach(() => {
        ({ proposals, hadSlowedProposal } = computeGoalProposals({
          direction: "gain",
          expenditureKcal: 2000,
          startingWeightTrendKg: 60,
          daysFromStartToDeadline: 56,
        }));
      });

      test("ゆるめ・標準・ハードの順に、1週に 0.15%・0.3%・0.5% ずつ増やした目標体重を、0.1kg 単位に切り捨てて返すこと", () => {
        // 8 週で 60 kg の 101.2%・102.4%・104% は、60.72・61.44・62.4 kg
        expect(proposals).toMatchObject([
          { pace: "gentle", status: "offered", targetWeightKg: 60.7 },
          { pace: "standard", status: "offered", targetWeightKg: 61.4 },
          { pace: "hard", status: "offered", targetWeightKg: 62.4 },
        ]);
      });

      test("速さを落とした案が無いと返すこと", () => {
        expect(hadSlowedProposal).toBe(false);
      });

      test("案ごとに、推定消費カロリーより多い1日の目安と、その差を返すこと", () => {
        expect(proposals).toMatchObject([
          { dailyGuide: { energyKcal: 2100, limitHits: [] }, dailyGuideDifferenceKcal: 100 },
          { dailyGuide: { energyKcal: 2200, limitHits: [] }, dailyGuideDifferenceKcal: 200 },
          { dailyGuide: { energyKcal: 2350, limitHits: [] }, dailyGuideDifferenceKcal: 350 },
        ]);
      });
    });

    describe("推定消費カロリーが 1,200 kcal を下回るとき", () => {
      let proposals: ReturnType<typeof computeGoalProposals>["proposals"];
      let hadSlowedProposal: boolean;

      beforeEach(() => {
        ({ proposals, hadSlowedProposal } = computeGoalProposals({
          direction: "gain",
          expenditureKcal: 1000,
          startingWeightTrendKg: 60,
          daysFromStartToDeadline: 56,
        }));
      });

      test("速さを落とした案が無いと返すこと", () => {
        expect(hadSlowedProposal).toBe(false);
      });

      test("速さを落とさず、3つの案を出すこと", () => {
        expect(proposals).toMatchObject([
          { pace: "gentle", status: "offered", targetWeightKg: 60.7 },
          { pace: "standard", status: "offered", targetWeightKg: 61.4 },
          { pace: "hard", status: "offered", targetWeightKg: 62.4 },
        ]);
      });
    });
  });
});
