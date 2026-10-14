import { beforeEach, describe, expect, test } from "vitest";
import { evaluateCustomTargetWeight } from "./index";

describe("自分で決める目標体重", () => {
  describe("減量で、ハード案の速さでも1日の目安が 1,200 kcal を下回らないとき", () => {
    // 72.4 kg から 12 週。ゆるめ・標準・ハードの案の目標体重は 70.3・68.1・65.9 kg
    let goal: {
      direction: "lose";
      expenditureKcal: number;
      startingWeightTrendKg: number;
      daysFromStartToDeadline: number;
    };

    beforeEach(() => {
      goal = {
        direction: "lose",
        expenditureKcal: 2250,
        startingWeightTrendKg: 72.4,
        daysFromStartToDeadline: 84,
      };
    });

    test("受け付ける目標体重に、1日の目安と推定消費カロリーとの差を返すこと", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 68.1 })).toMatchObject({
        status: "accepted",
        dailyGuide: {
          energyKcal: 1850,
          proteinG: 110,
          fatG: 50,
          carbohydrateG: 240,
          limitHits: [],
        },
        dailyGuideDifferenceKcal: -400,
      });
    });

    test("体重の傾向と同じ目標体重を、向きの側に出ないとして受け付けず、体重の傾向の 0.1kg 下を返すこと", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 72.4 })).toEqual({
        status: "rejected",
        reason: "not_on_direction_side",
        nearestAcceptedTargetWeightKg: 72.3,
      });
    });

    test("体重の傾向の 0.1kg 下の目標体重を、大変さをゆるめとして受け付けること", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 72.3 })).toMatchObject({
        status: "accepted",
        difficulty: "gentle",
      });
    });

    test("ゆるめの案の目標体重の大変さを、ゆるめにすること", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 70.3 })).toMatchObject({
        status: "accepted",
        difficulty: "gentle",
      });
    });

    test("ゆるめの案より 0.1kg 軽い目標体重の大変さを、標準にすること", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 70.2 })).toMatchObject({
        status: "accepted",
        difficulty: "standard",
      });
    });

    test("標準の案の目標体重の大変さを、標準にすること", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 68.1 })).toMatchObject({
        status: "accepted",
        difficulty: "standard",
      });
    });

    test("標準の案より 0.1kg 軽い目標体重の大変さを、ハードにすること", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 68 })).toMatchObject({
        status: "accepted",
        difficulty: "hard",
      });
    });

    test("ハードの案の目標体重を、大変さをハードとして受け付けること", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 65.9 })).toMatchObject({
        status: "accepted",
        difficulty: "hard",
      });
    });

    test("ハードの案より 0.1kg 軽い目標体重を、速すぎるとして受け付けず、ハードの案の目標体重を返すこと", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 65.8 })).toEqual({
        status: "rejected",
        reason: "pace_too_fast",
        nearestAcceptedTargetWeightKg: 65.9,
      });
    });
  });

  describe("減量で、ハード案の速さだと1日の目安が 1,200 kcal を下回るとき", () => {
    // 1日に 300 kcal まで減らせて、84 日で 3.27 kg。60 − 3.27 は 56.73 kg
    let goal: {
      direction: "lose";
      expenditureKcal: number;
      startingWeightTrendKg: number;
      daysFromStartToDeadline: number;
    };

    beforeEach(() => {
      goal = {
        direction: "lose",
        expenditureKcal: 1500,
        startingWeightTrendKg: 60,
        daysFromStartToDeadline: 84,
      };
    });

    test("1日の目安が 1,200 kcal を下回らない、いちばん軽い目標体重を受け付けること", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 56.8 })).toMatchObject({
        status: "accepted",
        dailyGuide: { energyKcal: 1200, limitHits: [] },
      });
    });

    test("それより 0.1kg 軽い目標体重を、下限に当たるとして受け付けず、いちばん近い目標体重を返すこと", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 56.7 })).toEqual({
        status: "rejected",
        reason: "daily_guide_below_minimum",
        nearestAcceptedTargetWeightKg: 56.8,
      });
    });
  });

  describe("減量で、案を1つも出せないとき", () => {
    let goal: {
      direction: "lose";
      expenditureKcal: number;
      startingWeightTrendKg: number;
      daysFromStartToDeadline: number;
    };

    beforeEach(() => {
      goal = {
        direction: "lose",
        expenditureKcal: 1200,
        startingWeightTrendKg: 60,
        daysFromStartToDeadline: 84,
      };
    });

    test("体重の傾向より軽い目標体重を、下限に当たるとして受け付けず、いちばん近い目標体重を返さないこと", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 59 })).toEqual({
        status: "rejected",
        reason: "daily_guide_below_minimum",
        nearestAcceptedTargetWeightKg: undefined,
      });
    });
  });

  describe("増量のとき", () => {
    // 60 kg から 8 週。ゆるめ・標準・ハードの案の目標体重は 60.7・61.4・62.4 kg
    let goal: {
      direction: "gain";
      expenditureKcal: number;
      startingWeightTrendKg: number;
      daysFromStartToDeadline: number;
    };

    beforeEach(() => {
      goal = {
        direction: "gain",
        expenditureKcal: 2000,
        startingWeightTrendKg: 60,
        daysFromStartToDeadline: 56,
      };
    });

    test("体重の傾向と同じ目標体重を、向きの側に出ないとして受け付けず、体重の傾向の 0.1kg 上を返すこと", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 60 })).toEqual({
        status: "rejected",
        reason: "not_on_direction_side",
        nearestAcceptedTargetWeightKg: 60.1,
      });
    });

    test("ゆるめの案より 0.1kg 重い目標体重の大変さを、標準にすること", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 60.8 })).toMatchObject({
        status: "accepted",
        difficulty: "standard",
      });
    });

    test("ハードの案の目標体重を、大変さをハードとして受け付けること", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 62.4 })).toMatchObject({
        status: "accepted",
        difficulty: "hard",
        dailyGuide: { energyKcal: 2350, limitHits: [] },
        dailyGuideDifferenceKcal: 350,
      });
    });

    test("ハードの案より 0.1kg 重い目標体重を、速すぎるとして受け付けず、ハードの案の目標体重を返すこと", () => {
      expect(evaluateCustomTargetWeight({ ...goal, targetWeightKg: 62.5 })).toEqual({
        status: "rejected",
        reason: "pace_too_fast",
        nearestAcceptedTargetWeightKg: 62.4,
      });
    });
  });
});
