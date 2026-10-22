import { beforeEach, describe, expect, test } from "vitest";
import { sortSchedulesNewestFirst } from "./index";

describe("推定の予定を新しい順に並べる", () => {
  describe("予定の時刻が違うとき", () => {
    let schedules: { name: string; dueAt: Date; progress: string }[];
    beforeEach(() => {
      schedules = [
        { name: "古い", dueAt: new Date("2026-10-01T00:00:00Z"), progress: "waiting" },
        { name: "新しい", dueAt: new Date("2026-10-02T00:00:00Z"), progress: "held" },
      ];
    });

    test("時刻の遅い予定を先に並べること", () => {
      expect(sortSchedulesNewestFirst(schedules).map(({ name }) => name)).toEqual([
        "新しい",
        "古い",
      ]);
    });
  });

  describe("保留した予定と、同じ時刻に再開した予定があるとき", () => {
    let schedules: { name: string; dueAt: Date; progress: string }[];
    beforeEach(() => {
      schedules = [
        { name: "保留", dueAt: new Date("2026-10-01T00:00:00Z"), progress: "held" },
        { name: "再開", dueAt: new Date("2026-10-01T00:00:00Z"), progress: "waiting" },
      ];
    });

    test("再開した予定を先に並べること", () => {
      expect(sortSchedulesNewestFirst(schedules).map(({ name }) => name)).toEqual(["再開", "保留"]);
    });
  });

  describe("見送った予定と、同じ時刻の予定があるとき", () => {
    let schedules: { name: string; dueAt: Date; progress: string }[];
    beforeEach(() => {
      schedules = [
        { name: "見送り", dueAt: new Date("2026-10-01T00:00:00Z"), progress: "deferred" },
        { name: "次の予定", dueAt: new Date("2026-10-01T00:00:00Z"), progress: "estimating" },
      ];
    });

    test("見送った予定をあとに並べること", () => {
      expect(sortSchedulesNewestFirst(schedules).map(({ name }) => name)).toEqual([
        "次の予定",
        "見送り",
      ]);
    });
  });
});
