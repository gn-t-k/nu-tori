import { describe, expect, test } from "vitest";
import { computeNextDayStart } from "./index";

describe("次の日の 0:00", () => {
  describe("夏時間の無いタイムゾーンのとき", () => {
    test("その地方時の 0:00 を、次の日として返すこと", () => {
      expect(computeNextDayStart("2026-10-01", "Asia/Tokyo")).toEqual({
        countedOn: "2026-10-02",
        startsAt: new Date("2026-10-01T15:00:00Z"),
      });
    });

    test("分の端数の時差でも、その地方時の 0:00 を返すこと", () => {
      expect(computeNextDayStart("2026-10-01", "Asia/Kolkata")).toEqual({
        countedOn: "2026-10-02",
        startsAt: new Date("2026-10-01T18:30:00Z"),
      });
    });
  });

  describe("月末のとき", () => {
    test("翌月の 1 日を次の日として返すこと", () => {
      expect(computeNextDayStart("2026-12-31", "UTC")).toEqual({
        countedOn: "2027-01-01",
        startsAt: new Date("2027-01-01T00:00:00Z"),
      });
    });
  });

  describe("夏時間が始まる日の前日のとき", () => {
    test("切り替わったあとの時差で、次の日の 0:00 を返すこと", () => {
      // ニューヨークは 2026-03-08 の 2:00 に夏時間に入る。0:00 はまだ UTC-5
      expect(computeNextDayStart("2026-03-07", "America/New_York")).toEqual({
        countedOn: "2026-03-08",
        startsAt: new Date("2026-03-08T05:00:00Z"),
      });
    });
  });

  describe("夏時間が始まる日のとき", () => {
    test("夏時間に入ったあとの時差で、次の日の 0:00 を返すこと", () => {
      expect(computeNextDayStart("2026-03-08", "America/New_York")).toEqual({
        countedOn: "2026-03-09",
        startsAt: new Date("2026-03-09T04:00:00Z"),
      });
    });
  });
});
