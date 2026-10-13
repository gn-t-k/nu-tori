import type { AlarmJob } from "../alarm-job";
import { computeEarliestAlarmAt } from "../compute-earliest-alarm-at";

// アラーム1回分。仕事を並びの順に1つずつ進め、次に張る時刻と、報告するエラーを決める
export const runAlarmJobs = async <Stores, Deps, Report>(
  jobs: readonly AlarmJob<Stores, Deps, Report>[],
  stores: Stores,
  deps: Deps,
): Promise<{
  nextAlarmAt: Date | undefined;
  // 並びで先にある仕事のエラーを先に報告する。どれも進めば undefined
  error: unknown;
  reports: Report[];
}> => {
  const ran = [];
  for (const job of jobs) {
    // 前の仕事が書いたものを次の仕事が読むので、並べずに順に進める
    ran.push({ job, outcome: await job.advance(stores, deps) });
  }
  return {
    nextAlarmAt: computeEarliestAlarmAt(
      ran.filter(({ outcome }) => outcome.result !== "left_to_alarm_retry").map(({ job }) => job),
      stores,
      new Date(),
    ),
    error: ran.map(({ outcome }) => outcome).find((outcome) => outcome.result !== "advanced")
      ?.error,
    reports: ran.map(({ outcome }) => outcome.report),
  };
};
