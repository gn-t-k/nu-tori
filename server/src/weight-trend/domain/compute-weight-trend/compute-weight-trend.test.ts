import { beforeEach, describe, expect, test } from "vitest";
import type { WeightTrend } from "../weight-trend";
import { computeWeightTrend } from "./index";

describe("体重の傾向の計算", () => {
  describe("日の代表値が無いとき", () => {
    let trend: WeightTrend;

    beforeEach(() => {
      trend = computeWeightTrend([]);
    });

    test("傾向の日が無いこと", () => {
      expect(trend).toEqual([]);
    });
  });

  describe("代表値が1日だけのとき", () => {
    let trend: WeightTrend;

    beforeEach(() => {
      trend = computeWeightTrend([{ calendarDay: "2026-09-01", weightKg: 72.0 }]);
    });

    test("その日の傾向を、その日の代表値にすること", () => {
      expect(trend).toEqual([{ calendarDay: "2026-09-01", trendKg: 72.0 }]);
    });
  });

  describe("代表値の無い日を1日挟むとき", () => {
    let trend: WeightTrend;

    beforeEach(() => {
      trend = computeWeightTrend([
        { calendarDay: "2026-09-01", weightKg: 72.0 },
        { calendarDay: "2026-09-03", weightKg: 71.6 },
      ]);
    });

    test("始まりの日から最後の代表値の日まで、1日ずつ返すこと", () => {
      expect(trend.map(({ calendarDay }) => calendarDay)).toEqual([
        "2026-09-01",
        "2026-09-02",
        "2026-09-03",
      ]);
    });

    test("無い日を前後の代表値から埋め、重み 0.1 でならすこと", () => {
      expect(trend.map(({ trendKg }) => trendKg)).toEqual([
        72.0,
        expect.closeTo(71.98, 10),
        expect.closeTo(71.942, 10),
      ]);
    });
  });

  describe("代表値の無い日を2日挟み、月をまたぐとき", () => {
    let trend: WeightTrend;

    beforeEach(() => {
      trend = computeWeightTrend([
        { calendarDay: "2026-09-29", weightKg: 72.0 },
        { calendarDay: "2026-10-02", weightKg: 71.4 },
      ]);
    });

    test("月をまたいで1日ずつ返すこと", () => {
      expect(trend.map(({ calendarDay }) => calendarDay)).toEqual([
        "2026-09-29",
        "2026-09-30",
        "2026-10-01",
        "2026-10-02",
      ]);
    });

    test("無い日を日数で線形に埋めてならすこと", () => {
      // 埋めた値は 71.8 と 71.6
      expect(trend.map(({ trendKg }) => trendKg)).toEqual([
        72.0,
        expect.closeTo(71.98, 10),
        expect.closeTo(71.942, 10),
        expect.closeTo(71.8878, 10),
      ]);
    });
  });
});
