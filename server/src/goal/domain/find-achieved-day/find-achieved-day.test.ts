import { beforeEach, describe, expect, test } from "vitest";
import { addDays } from "../../../domain/add-days";
import { generateRecordId } from "../../../domain/record-id";
import { findAchievedDay } from "./index";

type Input = Parameters<typeof findAchievedDay>[0];

// 2026-10-01 から 74.0 kg で始め、70.0 kg を目指す減量の目標。期限は 2026-11-30
const losingGoal: Input["goal"] = {
  startedOn: "2026-10-01",
  startingWeightTrendKg: 74,
  targetWeightKg: 70,
  weightChange: { deadlineOn: "2026-11-30", pacePlan: "standard" },
  achievement: undefined,
  deadlineConfirmation: undefined,
  closure: undefined,
};

// 日ごとの体重の傾向を、from の日から順に並べる
const trendFrom = (from: string, trendKgs: readonly number[]) =>
  trendKgs.map((trendKg, offset) => ({ calendarDay: addDays(from, offset), trendKg }));

describe("達成した日", () => {
  let input: Input;

  describe("減量の目標で、体重の傾向が目標体重を下回ったとき", () => {
    beforeEach(() => {
      input = { goal: losingGoal, weightTrend: trendFrom("2026-11-01", [70.3, 70.1, 69.9, 69.8]) };
    });

    test("目標体重以下になった最初の日であること", () => {
      expect(findAchievedDay(input)).toBe("2026-11-03");
    });
  });

  describe("増量の目標で、体重の傾向が目標体重を上回ったとき", () => {
    beforeEach(() => {
      input = {
        goal: { ...losingGoal, startingWeightTrendKg: 60, targetWeightKg: 63 },
        weightTrend: trendFrom("2026-11-01", [62.8, 63.1, 63.2]),
      };
    });

    test("目標体重以上になった最初の日であること", () => {
      expect(findAchievedDay(input)).toBe("2026-11-02");
    });
  });

  describe("体重の傾向がちょうど目標体重の日があるとき", () => {
    beforeEach(() => {
      input = { goal: losingGoal, weightTrend: trendFrom("2026-11-01", [70.2, 70, 69.9]) };
    });

    test("その日を達成した日にすること", () => {
      expect(findAchievedDay(input)).toBe("2026-11-02");
    });
  });

  describe("目標体重に届いていないとき", () => {
    beforeEach(() => {
      input = { goal: losingGoal, weightTrend: trendFrom("2026-11-01", [70.3, 70.1, 70.05]) };
    });

    test("無いこと", () => {
      expect(findAchievedDay(input)).toBeUndefined();
    });
  });

  describe("開始の日より前にだけ目標体重に届いていたとき", () => {
    beforeEach(() => {
      input = { goal: losingGoal, weightTrend: trendFrom("2026-09-29", [69.5, 69.8, 70.4, 70.6]) };
    });

    test("無いこと", () => {
      expect(findAchievedDay(input)).toBeUndefined();
    });
  });

  describe("2026-11-03 に閉じた目標で", () => {
    let closedGoal: Input["goal"];
    beforeEach(() => {
      closedGoal = {
        ...losingGoal,
        closure: { endedOn: "2026-11-03", nextGoalId: generateRecordId(), endReason: "switched" },
      };
    });

    describe("閉じる日の前の日に目標体重に届いたとき", () => {
      beforeEach(() => {
        input = { goal: closedGoal, weightTrend: trendFrom("2026-11-01", [70.1, 70, 69.9]) };
      });

      test("その日を達成した日にすること", () => {
        expect(findAchievedDay(input)).toBe("2026-11-02");
      });
    });

    describe("閉じる日に初めて目標体重に届いたとき", () => {
      beforeEach(() => {
        input = { goal: closedGoal, weightTrend: trendFrom("2026-11-01", [70.2, 70.1, 69.9]) };
      });

      test("無いこと", () => {
        expect(findAchievedDay(input)).toBeUndefined();
      });
    });
  });

  describe("期限の日の結果を確定した目標で", () => {
    let confirmedGoal: Input["goal"];
    beforeEach(() => {
      confirmedGoal = {
        ...losingGoal,
        deadlineConfirmation: {
          deadlineWeightTrendKg: 70.4,
          confirmedAt: new Date("2026-12-01T00:00:00Z"),
          timeZone: "Asia/Tokyo",
        },
      };
    });

    describe("確定のあとに遅れて届いた体重で、期限の日以前に目標体重に届いたとき", () => {
      beforeEach(() => {
        input = { goal: confirmedGoal, weightTrend: trendFrom("2026-11-29", [70.1, 69.9]) };
      });

      test("無いこと", () => {
        expect(findAchievedDay(input)).toBeUndefined();
      });
    });

    describe("期限の日より後に目標体重に届いたとき", () => {
      beforeEach(() => {
        input = { goal: confirmedGoal, weightTrend: trendFrom("2026-11-29", [70.1, 69.9, 69.8]) };
      });

      test("期限の日より後で最初に届いた日であること", () => {
        expect(findAchievedDay(input)).toBe("2026-12-01");
      });
    });
  });

  describe("一度達成した目標で、あとで体重の傾向が目標体重を越えて戻ったとき", () => {
    beforeEach(() => {
      input = {
        goal: {
          ...losingGoal,
          achievement: {
            achievedOn: "2026-11-02",
            judgedAt: new Date("2026-11-02T00:00:00Z"),
            timeZone: "Asia/Tokyo",
          },
        },
        weightTrend: trendFrom("2026-11-01", [70.2, 70.4, 70.6]),
      };
    });

    test("達成した日を取り消さないこと", () => {
      expect(findAchievedDay(input)).toBe("2026-11-02");
    });
  });

  describe("維持の目標のとき", () => {
    beforeEach(() => {
      input = {
        goal: { ...losingGoal, weightChange: undefined },
        weightTrend: trendFrom("2026-11-01", [70, 69.9]),
      };
    });

    test("無いこと", () => {
      expect(findAchievedDay(input)).toBeUndefined();
    });
  });
});
