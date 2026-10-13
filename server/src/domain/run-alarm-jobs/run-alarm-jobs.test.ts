import { beforeEach, describe, expect, test } from "vitest";
import type { AlarmJob } from "../alarm-job";
import { runAlarmJobs } from "./index";

type FakeJob = AlarmJob<undefined, undefined, string>;

describe("アラームで動かす仕事の並びを回す", () => {
  describe("どの仕事も進んだとき", () => {
    let calls: string[];
    let jobs: FakeJob[];
    beforeEach(() => {
      calls = [];
      const createJob = (name: string, nextAt: Date | undefined): FakeJob => ({
        advance: async () => {
          calls.push(`${name}を始めた`);
          // 並べて進めていれば、ここで次の仕事が始まる
          await Promise.resolve();
          calls.push(`${name}を終えた`);
          return { result: "advanced", report: name };
        },
        computeNextAt: () => {
          calls.push(`${name}の次の時刻を出した`);
          return nextAt;
        },
      });
      jobs = [
        createJob("読み分け", new Date("2026-10-13T00:10:00.000Z")),
        createJob("推定", new Date("2026-10-13T00:05:00.000Z")),
        createJob("返事", undefined),
      ];
    });

    test("並びの順に1つずつ進め、すべて進めてから次の時刻を出すこと", async () => {
      await runAlarmJobs(jobs, undefined, undefined);

      expect(calls).toEqual([
        "読み分けを始めた",
        "読み分けを終えた",
        "推定を始めた",
        "推定を終えた",
        "返事を始めた",
        "返事を終えた",
        "読み分けの次の時刻を出した",
        "推定の次の時刻を出した",
        "返事の次の時刻を出した",
      ]);
    });

    test("仕事ごとの報告を、並びの順に返すこと", async () => {
      const ran = await runAlarmJobs(jobs, undefined, undefined);

      expect(ran.reports).toEqual(["読み分け", "推定", "返事"]);
    });

    test("いちばん早い時刻を、次に張る時刻にすること", async () => {
      const ran = await runAlarmJobs(jobs, undefined, undefined);

      expect(ran.nextAlarmAt).toEqual(new Date("2026-10-13T00:05:00.000Z"));
    });

    test("エラーを報告しないこと", async () => {
      const ran = await runAlarmJobs(jobs, undefined, undefined);

      expect(ran.error).toBeUndefined();
    });
  });

  describe("推定と返事が止まり、写真の控えの削除が失敗したとき", () => {
    let estimationError: Error;
    let jobs: FakeJob[];
    beforeEach(() => {
      estimationError = new Error("推定が止まった");
      jobs = [
        {
          advance: async () => ({ result: "advanced", report: "読み分け" }),
          computeNextAt: () => undefined,
        },
        {
          advance: async () => ({ result: "stopped", error: estimationError, report: "推定" }),
          computeNextAt: () => new Date("2026-10-13T00:05:00.000Z"),
        },
        {
          advance: async () => ({
            result: "stopped",
            error: new Error("返事が止まった"),
            report: "返事",
          }),
          computeNextAt: () => new Date("2026-10-13T00:10:00.000Z"),
        },
        {
          advance: async () => ({
            result: "left_to_alarm_retry",
            error: new Error("削除に失敗した"),
            report: "削除",
          }),
          computeNextAt: () => new Date("2026-10-13T00:00:00.000Z"),
        },
      ];
    });

    test("推定の止まりを報告すること", async () => {
      const ran = await runAlarmJobs(jobs, undefined, undefined);

      expect(ran.error).toBe(estimationError);
    });

    test("止まった仕事の時刻には張り直し、アラームのやり直しに任せる仕事の時刻には張り直さないこと", async () => {
      const ran = await runAlarmJobs(jobs, undefined, undefined);

      expect(ran.nextAlarmAt).toEqual(new Date("2026-10-13T00:05:00.000Z"));
    });

    test("エラーのあとの仕事も進めること", async () => {
      const ran = await runAlarmJobs(jobs, undefined, undefined);

      expect(ran.reports).toEqual(["読み分け", "推定", "返事", "削除"]);
    });
  });

  describe("返事が止まり、写真の控えの削除が失敗したとき", () => {
    let replyError: Error;
    let jobs: FakeJob[];
    beforeEach(() => {
      replyError = new Error("返事が止まった");
      jobs = [
        {
          advance: async () => ({ result: "advanced", report: "推定" }),
          computeNextAt: () => undefined,
        },
        {
          advance: async () => ({ result: "stopped", error: replyError, report: "返事" }),
          computeNextAt: () => undefined,
        },
        {
          advance: async () => ({
            result: "left_to_alarm_retry",
            error: new Error("削除に失敗した"),
            report: "削除",
          }),
          computeNextAt: () => new Date("2026-10-13T00:00:00.000Z"),
        },
      ];
    });

    test("返事の止まりを報告すること", async () => {
      const ran = await runAlarmJobs(jobs, undefined, undefined);

      expect(ran.error).toBe(replyError);
    });

    test("ほかに次の時刻が無ければ、張り直さないこと", async () => {
      const ran = await runAlarmJobs(jobs, undefined, undefined);

      expect(ran.nextAlarmAt).toBeUndefined();
    });
  });

  describe("写真の控えの削除だけが失敗したとき", () => {
    let deletionError: Error;
    let jobs: FakeJob[];
    beforeEach(() => {
      deletionError = new Error("削除に失敗した");
      jobs = [
        {
          advance: async () => ({ result: "advanced", report: "推定" }),
          computeNextAt: () => undefined,
        },
        {
          advance: async () => ({
            result: "left_to_alarm_retry",
            error: deletionError,
            report: "削除",
          }),
          computeNextAt: () => new Date("2026-10-13T00:00:00.000Z"),
        },
      ];
    });

    test("削除のエラーを報告すること", async () => {
      const ran = await runAlarmJobs(jobs, undefined, undefined);

      expect(ran.error).toBe(deletionError);
    });
  });
});
