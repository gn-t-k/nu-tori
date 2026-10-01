import { beforeEach, describe, expect, test } from "vitest";
import type { EstimationAttempt } from "../estimation-store";
import { computeNextEstimationAttemptAt } from "./compute-next-estimation-attempt-at";

describe("次に試みる時刻", () => {
  describe("最初の試みが終わって、やり直すとき", () => {
    let attempts: EstimationAttempt[];
    beforeEach(() => {
      attempts = [
        {
          attemptedAt: new Date("2026-10-01T03:00:00Z"),
          ended: {
            endedAt: new Date("2026-10-01T03:00:20Z"),
            conclusion: { result: "provider_error", errorType: "overloaded_error" },
          },
        },
      ];
    });

    test("始めた時刻の 15 秒後であること", () => {
      expect(computeNextEstimationAttemptAt(attempts)).toEqual(new Date("2026-10-01T03:00:15Z"));
    });
  });

  describe("3つ目の試みが終わって、やり直すとき", () => {
    let attempts: EstimationAttempt[];
    beforeEach(() => {
      attempts = [
        { attemptedAt: new Date("2026-10-01T03:00:00Z"), ended: undefined },
        { attemptedAt: new Date("2026-10-01T03:04:00Z"), ended: undefined },
        {
          attemptedAt: new Date("2026-10-01T03:08:00Z"),
          ended: {
            endedAt: new Date("2026-10-01T03:08:10Z"),
            conclusion: { result: "timed_out" },
          },
        },
      ];
    });

    test("待ちを広げ、始めた時刻の 60 秒後であること", () => {
      expect(computeNextEstimationAttemptAt(attempts)).toEqual(new Date("2026-10-01T03:09:00Z"));
    });
  });

  describe("2つ目の試みに結果が無いとき", () => {
    let attempts: EstimationAttempt[];
    beforeEach(() => {
      attempts = [
        {
          attemptedAt: new Date("2026-10-01T03:00:00Z"),
          ended: {
            endedAt: new Date("2026-10-01T03:00:20Z"),
            conclusion: { result: "invalid_response" },
          },
        },
        { attemptedAt: new Date("2026-10-01T03:01:00Z"), ended: undefined },
      ];
    });

    test("呼び出しの時間の上限の 3 分を待ってから、さらに 30 秒後であること", () => {
      expect(computeNextEstimationAttemptAt(attempts)).toEqual(new Date("2026-10-01T03:04:30Z"));
    });
  });
});
