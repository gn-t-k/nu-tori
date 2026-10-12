import type { AlarmJob } from "../alarm-job";

// Durable Object のアラームは一度に1つなので、仕事ごとの次の時刻のいちばん早いものに合わせる。どれも無ければ undefined
export const computeEarliestAlarmAt = <Stores>(
  jobs: readonly Pick<AlarmJob<Stores, never, unknown>, "computeNextAt">[],
  stores: Stores,
  now: Date,
): Date | undefined =>
  jobs
    .map((job) => job.computeNextAt(stores, now))
    .filter((nextAt) => nextAt !== undefined)
    .toSorted((a, b) => a.getTime() - b.getTime())[0];
