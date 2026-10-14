import { beforeEach, describe, expect, test } from "vitest";
import { excludePartiallyRecordedDays } from "./index";

describe("部分的な記録の日を外す", () => {
  describe("食べた量のある日が7日で、1日が中央値の半分に満たないとき", () => {
    let days: { calendarDay: string; kcal: number }[];

    beforeEach(() => {
      days = excludePartiallyRecordedDays([
        { calendarDay: "2026-10-01", kcal: 2000 },
        { calendarDay: "2026-10-02", kcal: 2000 },
        { calendarDay: "2026-10-03", kcal: 999 },
        { calendarDay: "2026-10-04", kcal: 2000 },
        { calendarDay: "2026-10-05", kcal: 2000 },
        { calendarDay: "2026-10-06", kcal: 2000 },
        { calendarDay: "2026-10-07", kcal: 2000 },
      ]);
    });

    test("その日を外し、ほかの日を残すこと", () => {
      expect(days.map(({ calendarDay }) => calendarDay)).toEqual([
        "2026-10-01",
        "2026-10-02",
        "2026-10-04",
        "2026-10-05",
        "2026-10-06",
        "2026-10-07",
      ]);
    });
  });

  describe("食べた量のある日が7日で、1日が中央値のちょうど半分のとき", () => {
    let days: { calendarDay: string; kcal: number }[];

    beforeEach(() => {
      days = excludePartiallyRecordedDays([
        { calendarDay: "2026-10-01", kcal: 2000 },
        { calendarDay: "2026-10-02", kcal: 2000 },
        { calendarDay: "2026-10-03", kcal: 1000 },
        { calendarDay: "2026-10-04", kcal: 2000 },
        { calendarDay: "2026-10-05", kcal: 2000 },
        { calendarDay: "2026-10-06", kcal: 2000 },
        { calendarDay: "2026-10-07", kcal: 2000 },
      ]);
    });

    test("どの日も外さないこと", () => {
      expect(days).toHaveLength(7);
    });
  });

  describe("食べた量のある日が6日で、1日が中央値の半分に満たないとき", () => {
    let days: { calendarDay: string; kcal: number }[];

    beforeEach(() => {
      days = excludePartiallyRecordedDays([
        { calendarDay: "2026-10-01", kcal: 2000 },
        { calendarDay: "2026-10-02", kcal: 2000 },
        { calendarDay: "2026-10-03", kcal: 999 },
        { calendarDay: "2026-10-04", kcal: 2000 },
        { calendarDay: "2026-10-05", kcal: 2000 },
        { calendarDay: "2026-10-06", kcal: 2000 },
      ]);
    });

    test("どの日も外さないこと", () => {
      expect(days).toHaveLength(6);
    });
  });

  describe("食べた量のある日が8日で、まん中の2日の平均の半分に満たない日があるとき", () => {
    let days: { calendarDay: string; kcal: number }[];

    beforeEach(() => {
      // 並べると 990・1600・1600・1600・2400・2400・2400・2400 で、中央値は 2000
      days = excludePartiallyRecordedDays([
        { calendarDay: "2026-10-01", kcal: 1600 },
        { calendarDay: "2026-10-02", kcal: 2400 },
        { calendarDay: "2026-10-03", kcal: 1600 },
        { calendarDay: "2026-10-04", kcal: 2400 },
        { calendarDay: "2026-10-05", kcal: 990 },
        { calendarDay: "2026-10-06", kcal: 2400 },
        { calendarDay: "2026-10-07", kcal: 1600 },
        { calendarDay: "2026-10-08", kcal: 2400 },
      ]);
    });

    test("その日を外すこと", () => {
      expect(days.map(({ kcal }) => kcal)).toEqual([1600, 2400, 1600, 2400, 2400, 1600, 2400]);
    });
  });
});
