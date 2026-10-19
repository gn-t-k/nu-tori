import { beforeEach, describe, expect, test } from "vitest";
import type { WeightTrend } from "../weight-trend";
import { findWeightTrendOnOrBefore } from "./index";

describe("ある日の体重の傾向", () => {
  let trend: WeightTrend;

  beforeEach(() => {
    trend = [
      { calendarDay: "2026-09-01", trendKg: 72.0 },
      { calendarDay: "2026-09-02", trendKg: 71.9 },
      { calendarDay: "2026-09-03", trendKg: 71.8 },
    ];
  });

  describe("その日に体重の傾向があるとき", () => {
    test("その日の値を返すこと", () => {
      expect(findWeightTrendOnOrBefore(trend, "2026-09-02")).toEqual({
        calendarDay: "2026-09-02",
        trendKg: 71.9,
      });
    });
  });

  describe("その日が最後の体重記録の日より後のとき", () => {
    test("最後の体重記録の日の値を返すこと", () => {
      expect(findWeightTrendOnOrBefore(trend, "2026-09-10")).toEqual({
        calendarDay: "2026-09-03",
        trendKg: 71.8,
      });
    });
  });

  describe("その日が最初の体重記録の日より前のとき", () => {
    test("値が無いこと", () => {
      expect(findWeightTrendOnOrBefore(trend, "2026-08-31")).toBeUndefined();
    });
  });
});
