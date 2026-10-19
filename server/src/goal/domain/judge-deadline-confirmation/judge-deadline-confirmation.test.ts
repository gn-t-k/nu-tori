import { describe, expect, test } from "vitest";
import { addDays } from "../../../domain/add-days";
import { generateRecordId } from "../../../domain/record-id";
import type { DeadlineConfirmationGoal } from "./judge-deadline-confirmation";
import { judgeDeadlineConfirmation } from "./index";

// 期限が 2026-11-30 の減量の目標
const goal: DeadlineConfirmationGoal = {
  weightChange: { deadlineOn: "2026-11-30", pacePlan: "standard" },
  deadlineConfirmation: undefined,
  closure: undefined,
};

const trendFrom = (from: string, trendKgs: readonly number[]) =>
  trendKgs.map((trendKg, offset) => ({ calendarDay: addDays(from, offset), trendKg }));

// 11月28日〜12月1日の体重の傾向。期限の日は 70.4 kg
const weightTrend = trendFrom("2026-11-28", [70.6, 70.5, 70.4, 70.2]);

const closedOn = (endedOn: string): DeadlineConfirmationGoal => ({
  ...goal,
  closure: { endedOn, nextGoalId: generateRecordId(), endReason: "switched" },
});

describe("期限の日の結果の確定", () => {
  test("期限の日のうちは確定しないこと", () => {
    expect(judgeDeadlineConfirmation({ goal, today: "2026-11-30", weightTrend })).toBeUndefined();
  });

  test("期限の日の翌日の最初の要求で、期限の日の体重の傾向を確定すること", () => {
    expect(judgeDeadlineConfirmation({ goal, today: "2026-12-01", weightTrend })).toEqual({
      deadlineWeightTrendKg: 70.4,
    });
  });

  test("期限の日に体重の傾向が無ければ、それより前で最も新しい傾向を持ち越して確定すること", () => {
    expect(
      judgeDeadlineConfirmation({
        goal,
        today: "2026-12-03",
        weightTrend: trendFrom("2026-11-26", [70.8, 70.7]),
      }),
    ).toEqual({ deadlineWeightTrendKg: 70.7 });
  });

  test("期限の日に立て直して閉じた目標も、期限の日のあとに確定すること", () => {
    expect(
      judgeDeadlineConfirmation({ goal: closedOn("2026-11-30"), today: "2026-12-01", weightTrend }),
    ).toEqual({ deadlineWeightTrendKg: 70.4 });
  });

  test("期限の日の前の日に閉じた目標は確定しないこと", () => {
    expect(
      judgeDeadlineConfirmation({ goal: closedOn("2026-11-29"), today: "2026-12-01", weightTrend }),
    ).toBeUndefined();
  });

  test("一度確定した目標は、あとで期限の日の体重の傾向が変わっても確定し直さないこと", () => {
    expect(
      judgeDeadlineConfirmation({
        goal: {
          ...goal,
          deadlineConfirmation: {
            deadlineWeightTrendKg: 70.6,
            confirmedAt: new Date("2026-12-01T00:00:00Z"),
            timeZone: "Asia/Tokyo",
          },
        },
        today: "2026-12-02",
        weightTrend,
      }),
    ).toBeUndefined();
  });

  test("維持の目標は確定しないこと", () => {
    expect(
      judgeDeadlineConfirmation({
        goal: { ...goal, weightChange: undefined },
        today: "2026-12-01",
        weightTrend,
      }),
    ).toBeUndefined();
  });
});
