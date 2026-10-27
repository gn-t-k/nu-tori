import { beforeEach, describe, expect, test } from "vitest";
import type { EstimationSchedule } from "../estimation-schedule";
import { computeEstimationStatus } from "./index";

const receivedAt = new Date("2026-01-01T03:00:00Z");
const nextDayStartsAt = new Date("2026-01-01T15:00:00Z");
const resumedAt = new Date("2026-01-03T03:00:00Z");

describe("推定の予定から推定の状態を出す", () => {
  describe("予定が無いとき", () => {
    let schedules: EstimationSchedule[];
    beforeEach(() => {
      schedules = [];
    });

    test("値を持たないこと", () => {
      expect(computeEstimationStatus(schedules)).toBeUndefined();
    });
  });

  describe("いちばん新しい予定が、まだ推定を始めていないとき", () => {
    describe("前の予定が無いとき", () => {
      let schedules: EstimationSchedule[];
      beforeEach(() => {
        schedules = [{ scheduleId: "schedule-1", dueAt: receivedAt, progress: "waiting" }];
      });

      test("推定中にすること", () => {
        expect(computeEstimationStatus(schedules)).toBe("estimating");
      });
    });

    describe("すぐ前の予定が見送りのとき", () => {
      let schedules: EstimationSchedule[];
      beforeEach(() => {
        schedules = [
          { scheduleId: "schedule-1", dueAt: receivedAt, progress: "deferred" },
          { scheduleId: "schedule-2", dueAt: nextDayStartsAt, progress: "waiting" },
        ];
      });

      test("翌日に推定にすること", () => {
        expect(computeEstimationStatus(schedules)).toBe("deferred_to_next_day");
      });
    });

    describe("見送ったあとの次の日の予定が保留になり、課金で再開したとき", () => {
      let schedules: EstimationSchedule[];
      beforeEach(() => {
        schedules = [
          { scheduleId: "schedule-1", dueAt: receivedAt, progress: "deferred" },
          { scheduleId: "schedule-2", dueAt: nextDayStartsAt, progress: "held" },
          { scheduleId: "schedule-3", dueAt: resumedAt, progress: "waiting" },
        ];
      });

      test("推定中にすること", () => {
        expect(computeEstimationStatus(schedules)).toBe("estimating");
      });
    });

    describe("保留した予定と、同じ時刻に再開した予定があるとき", () => {
      let schedules: EstimationSchedule[];
      beforeEach(() => {
        schedules = [
          { scheduleId: "schedule-1", dueAt: receivedAt, progress: "deferred" },
          { scheduleId: "schedule-2", dueAt: nextDayStartsAt, progress: "held" },
          { scheduleId: "schedule-3", dueAt: nextDayStartsAt, progress: "waiting" },
        ];
      });

      test("推定中にすること", () => {
        expect(computeEstimationStatus(schedules)).toBe("estimating");
      });
    });

    describe("見送ったあとの次の日に推定を終え、そのあと名前を直したとき", () => {
      let schedules: EstimationSchedule[];
      beforeEach(() => {
        schedules = [
          { scheduleId: "schedule-1", dueAt: receivedAt, progress: "deferred" },
          {
            scheduleId: "schedule-2",
            dueAt: nextDayStartsAt,
            progress: "estimated",
            estimationId: "estimation-1",
          },
          { scheduleId: "schedule-3", dueAt: resumedAt, progress: "waiting" },
        ];
      });

      test("推定中にすること", () => {
        expect(computeEstimationStatus(schedules)).toBe("estimating");
      });
    });
  });

  describe("いちばん新しい予定が保留のとき", () => {
    let schedules: EstimationSchedule[];
    beforeEach(() => {
      schedules = [{ scheduleId: "schedule-1", dueAt: receivedAt, progress: "held" }];
    });

    test("サブスクリプションを待っているにすること", () => {
      expect(computeEstimationStatus(schedules)).toBe("awaiting_subscription");
    });
  });

  describe("いちばん新しい予定の推定を断念したとき", () => {
    let schedules: EstimationSchedule[];
    beforeEach(() => {
      schedules = [
        {
          scheduleId: "schedule-1",
          dueAt: receivedAt,
          progress: "abandoned",
          estimationId: "estimation-1",
        },
      ];
    });

    test("推定できなかったにすること", () => {
      expect(computeEstimationStatus(schedules)).toBe("failed");
    });
  });

  describe("いちばん新しい予定を取り消したとき", () => {
    let schedules: EstimationSchedule[];
    beforeEach(() => {
      schedules = [
        {
          scheduleId: "schedule-1",
          dueAt: receivedAt,
          progress: "estimated",
          estimationId: "estimation-1",
        },
        { scheduleId: "schedule-2", dueAt: resumedAt, progress: "cancelled" },
      ];
    });

    test("取り消していない予定のうち、いちばん新しい予定で決めること", () => {
      expect(computeEstimationStatus(schedules)).toBe("estimated");
    });
  });
});
