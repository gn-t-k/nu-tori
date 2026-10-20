import { beforeEach, describe, expect, test } from "vitest";
import { planPostDeadlineMaintenance } from "./index";
import { trendFrom } from "../testing/trend-from";

type Input = Parameters<typeof planPostDeadlineMaintenance>[0];

// 期限が 2026-11-29（日曜）の減量の目標。2026-11-30 と 2026-12-07 は月曜
const goal: Input["goal"] = {
  startingWeightTrendKg: 74,
  targetWeightKg: 70,
  weightChange: { deadlineOn: "2026-11-29", pacePlan: "standard" },
};

describe("期限後の維持", () => {
  let input: Input;

  describe("期限の日より後の最初の月曜のとき", () => {
    beforeEach(() => {
      input = {
        goal,
        reviewedMonday: "2026-11-30",
        weightTrend: trendFrom("2026-11-28", [70.62, 70.54, 70.48]),
      };
    });

    test("その前の日曜の体重の傾向を保つ維持へ移ること", () => {
      expect(planPostDeadlineMaintenance(input)).toEqual({
        targetWeightKg: 70.5,
        startingWeightTrendKg: 70.54,
      });
    });
  });

  describe("期限の日を含む週の月曜のとき", () => {
    beforeEach(() => {
      input = {
        goal: { ...goal, weightChange: { deadlineOn: "2026-11-30", pacePlan: "standard" } },
        reviewedMonday: "2026-11-30",
        weightTrend: trendFrom("2026-11-28", [70.62, 70.54, 70.48]),
      };
    });

    test("移らないこと", () => {
      expect(planPostDeadlineMaintenance(input)).toBeUndefined();
    });
  });

  describe("その週に体重が無いとき", () => {
    beforeEach(() => {
      input = {
        goal,
        reviewedMonday: "2026-12-07",
        weightTrend: trendFrom("2026-11-26", [70.9, 70.81]),
      };
    });

    test("最後に体重を量った日から持ち越した傾向を保つこと", () => {
      expect(planPostDeadlineMaintenance(input)).toEqual({
        targetWeightKg: 70.8,
        startingWeightTrendKg: 70.81,
      });
    });
  });

  describe("維持の目標のとき", () => {
    beforeEach(() => {
      input = {
        goal: { ...goal, weightChange: undefined },
        reviewedMonday: "2026-11-30",
        weightTrend: trendFrom("2026-11-28", [70.6]),
      };
    });

    test("移らないこと", () => {
      expect(planPostDeadlineMaintenance(input)).toBeUndefined();
    });
  });
});
