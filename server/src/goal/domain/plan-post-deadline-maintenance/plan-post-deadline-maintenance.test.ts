import { describe, expect, test } from "vitest";
import { addDays } from "../../../domain/add-days";
import type { PostDeadlineMaintenanceGoal } from "./plan-post-deadline-maintenance";
import { planPostDeadlineMaintenance } from "./index";

// 期限が 2026-11-29（日曜）の減量の目標。2026-11-30 と 2026-12-07 は月曜
const goal: PostDeadlineMaintenanceGoal = {
  startingWeightTrendKg: 74,
  targetWeightKg: 70,
  weightChange: { deadlineOn: "2026-11-29", pacePlan: "standard" },
};

const trendFrom = (from: string, trendKgs: readonly number[]) =>
  trendKgs.map((trendKg, offset) => ({ calendarDay: addDays(from, offset), trendKg }));

describe("期限後の維持", () => {
  test("期限の日より後の最初の月曜に、その前の日曜の体重の傾向を保つ維持へ移ること", () => {
    expect(
      planPostDeadlineMaintenance({
        goal,
        reviewedMonday: "2026-11-30",
        weightTrend: trendFrom("2026-11-28", [70.62, 70.54, 70.48]),
      }),
    ).toEqual({ targetWeightKg: 70.5, startingWeightTrendKg: 70.54 });
  });

  test("期限の日を含む週の月曜には移らないこと", () => {
    expect(
      planPostDeadlineMaintenance({
        goal: { ...goal, weightChange: { deadlineOn: "2026-11-30", pacePlan: "standard" } },
        reviewedMonday: "2026-11-30",
        weightTrend: trendFrom("2026-11-28", [70.62, 70.54, 70.48]),
      }),
    ).toBeUndefined();
  });

  test("その週に体重が無ければ、最後に体重を量った日から持ち越した傾向を保つこと", () => {
    expect(
      planPostDeadlineMaintenance({
        goal,
        reviewedMonday: "2026-12-07",
        weightTrend: trendFrom("2026-11-26", [70.9, 70.81]),
      }),
    ).toEqual({ targetWeightKg: 70.8, startingWeightTrendKg: 70.81 });
  });

  test("維持の目標は移らないこと", () => {
    expect(
      planPostDeadlineMaintenance({
        goal: { ...goal, weightChange: undefined },
        reviewedMonday: "2026-11-30",
        weightTrend: trendFrom("2026-11-28", [70.6]),
      }),
    ).toBeUndefined();
  });
});
