import { describe, expect, test } from "vitest";
import { addDays } from "../../../domain/add-days";
import { generateRecordId } from "../../../domain/record-id";
import type { AchievementGoal } from "./find-achieved-day";
import { findAchievedDay } from "./index";

// 2026-10-01 から 74.0 kg で始め、70.0 kg を目指す減量の目標。期限は 2026-11-30
const losingGoal: AchievementGoal = {
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
  test("減量では、体重の傾向が目標体重以下になった最初の日であること", () => {
    expect(
      findAchievedDay({
        goal: losingGoal,
        weightTrend: trendFrom("2026-11-01", [70.3, 70.1, 69.9, 69.8]),
      }),
    ).toBe("2026-11-03");
  });

  test("増量では、体重の傾向が目標体重以上になった最初の日であること", () => {
    expect(
      findAchievedDay({
        goal: { ...losingGoal, startingWeightTrendKg: 60, targetWeightKg: 63 },
        weightTrend: trendFrom("2026-11-01", [62.8, 63.1, 63.2]),
      }),
    ).toBe("2026-11-02");
  });

  test("体重の傾向がちょうど目標体重の日を達成した日にすること", () => {
    expect(
      findAchievedDay({
        goal: losingGoal,
        weightTrend: trendFrom("2026-11-01", [70.2, 70, 69.9]),
      }),
    ).toBe("2026-11-02");
  });

  test("目標体重に届いていなければ無いこと", () => {
    expect(
      findAchievedDay({
        goal: losingGoal,
        weightTrend: trendFrom("2026-11-01", [70.3, 70.1, 70.05]),
      }),
    ).toBeUndefined();
  });

  test("開始の日より前の日は達成した日にしないこと", () => {
    expect(
      findAchievedDay({
        goal: losingGoal,
        weightTrend: trendFrom("2026-09-29", [69.5, 69.8, 70.4, 70.6]),
      }),
    ).toBeUndefined();
  });

  test("目標が閉じる日の前の日まで探し、閉じる日からあとは達成した日にしないこと", () => {
    const closure = { endedOn: "2026-11-03", nextGoalId: generateRecordId() };
    expect({
      beforeClosure: findAchievedDay({
        goal: { ...losingGoal, closure: { ...closure, endReason: "switched" } },
        weightTrend: trendFrom("2026-11-01", [70.1, 70, 69.9]),
      }),
      onClosure: findAchievedDay({
        goal: { ...losingGoal, closure: { ...closure, endReason: "switched" } },
        weightTrend: trendFrom("2026-11-01", [70.2, 70.1, 69.9]),
      }),
    }).toEqual({ beforeClosure: "2026-11-02", onClosure: undefined });
  });

  test("期限の日の結果を確定したあとは、期限の日より後の日だけを達成した日にすること", () => {
    const confirmed: AchievementGoal = {
      ...losingGoal,
      deadlineConfirmation: {
        deadlineWeightTrendKg: 70.4,
        confirmedAt: new Date("2026-12-01T00:00:00Z"),
        timeZone: "Asia/Tokyo",
      },
    };
    expect({
      // 確定のあとに遅れて届いた、期限の日以前の体重で届いた
      lateRecordOnDeadline: findAchievedDay({
        goal: confirmed,
        weightTrend: trendFrom("2026-11-29", [70.1, 69.9]),
      }),
      afterDeadline: findAchievedDay({
        goal: confirmed,
        weightTrend: trendFrom("2026-11-29", [70.1, 69.9, 69.8]),
      }),
    }).toEqual({ lateRecordOnDeadline: undefined, afterDeadline: "2026-12-01" });
  });

  test("一度達成した日は、あとで体重の傾向が目標体重を越えて戻っても取り消さないこと", () => {
    expect(
      findAchievedDay({
        goal: {
          ...losingGoal,
          achievement: {
            achievedOn: "2026-11-02",
            judgedAt: new Date("2026-11-02T00:00:00Z"),
            timeZone: "Asia/Tokyo",
          },
        },
        weightTrend: trendFrom("2026-11-01", [70.2, 70.4, 70.6]),
      }),
    ).toBe("2026-11-02");
  });

  test("維持の目標には無いこと", () => {
    expect(
      findAchievedDay({
        goal: { ...losingGoal, weightChange: undefined },
        weightTrend: trendFrom("2026-11-01", [70, 69.9]),
      }),
    ).toBeUndefined();
  });
});
