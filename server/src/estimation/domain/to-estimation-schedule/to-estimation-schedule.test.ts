import { beforeEach, describe, expect, test } from "vitest";
import { type EstimationScheduleEvents, toEstimationSchedule } from "./index";

const dueAt = new Date("2026-01-01T03:00:00Z");
const noEvents: EstimationScheduleEvents = {
  scheduleId: "schedule-1",
  dueAt,
  cancellation: null,
  deferral: null,
  hold: null,
  estimation: null,
  completion: null,
  abandonment: null,
};

describe("予定の出来事から予定の進み具合を出す", () => {
  describe("出来事が無いとき", () => {
    let events: EstimationScheduleEvents;
    beforeEach(() => {
      events = noEvents;
    });

    test("待っているにすること", () => {
      expect(toEstimationSchedule(events)).toEqual({
        scheduleId: "schedule-1",
        dueAt,
        progress: "waiting",
      });
    });
  });

  describe("取り消しの行があるとき", () => {
    let events: EstimationScheduleEvents;
    beforeEach(() => {
      events = { ...noEvents, cancellation: "schedule-1", deferral: "schedule-1" };
    });

    test("ほかの出来事より先に、取り消したにすること", () => {
      expect(toEstimationSchedule(events)).toEqual({
        scheduleId: "schedule-1",
        dueAt,
        progress: "cancelled",
      });
    });
  });

  describe("見送りの行があるとき", () => {
    let events: EstimationScheduleEvents;
    beforeEach(() => {
      events = { ...noEvents, deferral: "schedule-1" };
    });

    test("見送ったにすること", () => {
      expect(toEstimationSchedule(events)).toEqual({
        scheduleId: "schedule-1",
        dueAt,
        progress: "deferred",
      });
    });
  });

  describe("保留の行があるとき", () => {
    let events: EstimationScheduleEvents;
    beforeEach(() => {
      events = { ...noEvents, hold: "schedule-1" };
    });

    test("保留したにすること", () => {
      expect(toEstimationSchedule(events)).toEqual({
        scheduleId: "schedule-1",
        dueAt,
        progress: "held",
      });
    });
  });

  describe("推定を始め、完了も断念もしていないとき", () => {
    let events: EstimationScheduleEvents;
    beforeEach(() => {
      events = { ...noEvents, estimation: "estimation-1" };
    });

    test("推定中にし、始めた推定を持たせること", () => {
      expect(toEstimationSchedule(events)).toEqual({
        scheduleId: "schedule-1",
        dueAt,
        progress: "estimating",
        estimationId: "estimation-1",
      });
    });
  });

  describe("推定を料理なしで完了したとき", () => {
    let events: EstimationScheduleEvents;
    beforeEach(() => {
      events = { ...noEvents, estimation: "estimation-1", completion: "no_dishes" };
    });

    test("料理なしにすること", () => {
      expect(toEstimationSchedule(events)).toEqual({
        scheduleId: "schedule-1",
        dueAt,
        progress: "no_dishes",
        estimationId: "estimation-1",
      });
    });
  });

  describe("推定を断念したとき", () => {
    let events: EstimationScheduleEvents;
    beforeEach(() => {
      events = { ...noEvents, estimation: "estimation-1", abandonment: "estimation-1" };
    });

    test("断念したにすること", () => {
      expect(toEstimationSchedule(events)).toEqual({
        scheduleId: "schedule-1",
        dueAt,
        progress: "abandoned",
        estimationId: "estimation-1",
      });
    });
  });
});
