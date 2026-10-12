import { beforeEach, describe, expect, test } from "vitest";
import type { AlarmJob } from "../alarm-job";
import { computeEarliestAlarmAt } from "./index";

type FakeJob = AlarmJob<undefined, undefined, undefined>;

const createJobDueAt = (computeNextAt: FakeJob["computeNextAt"]): FakeJob => ({
  advance: async () => ({ result: "advanced", report: undefined }),
  computeNextAt,
});

describe("アラームで動かす仕事の、いちばん早い時刻", () => {
  let now: Date;
  beforeEach(() => {
    now = new Date("2026-10-13T00:00:00.000Z");
  });

  describe("次の時刻のある仕事がいくつもあるとき", () => {
    let jobs: FakeJob[];
    beforeEach(() => {
      jobs = [
        createJobDueAt(() => new Date("2026-10-13T00:10:00.000Z")),
        createJobDueAt(() => new Date("2026-10-13T00:05:00.000Z")),
        createJobDueAt(() => undefined),
        createJobDueAt(() => new Date("2026-10-13T00:20:00.000Z")),
      ];
    });

    test("並びの順によらず、いちばん早い時刻を返すこと", () => {
      expect(computeEarliestAlarmAt(jobs, undefined, now)).toEqual(
        new Date("2026-10-13T00:05:00.000Z"),
      );
    });
  });

  describe("今すぐ動く仕事と、過ぎた時刻の仕事があるとき", () => {
    let jobs: FakeJob[];
    beforeEach(() => {
      jobs = [
        createJobDueAt((_stores, current) => current),
        createJobDueAt(() => new Date("2026-10-12T23:59:00.000Z")),
      ];
    });

    test("過ぎた時刻を返すこと", () => {
      expect(computeEarliestAlarmAt(jobs, undefined, now)).toEqual(
        new Date("2026-10-12T23:59:00.000Z"),
      );
    });
  });

  describe("どの仕事にも次の時刻が無いとき", () => {
    let jobs: FakeJob[];
    beforeEach(() => {
      jobs = [createJobDueAt(() => undefined), createJobDueAt(() => undefined)];
    });

    test("undefined を返すこと", () => {
      expect(computeEarliestAlarmAt(jobs, undefined, now)).toBeUndefined();
    });
  });
});
