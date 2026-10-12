import type { AlarmJob } from "../alarm-job";
import { findEarliest } from "../find-earliest";

// Durable Object のアラームは一度に1つなので、仕事ごとの次の時刻のいちばん早いものに合わせる。どれも無ければ undefined
export const computeEarliestAlarmAt = <Stores>(
  jobs: readonly Pick<AlarmJob<Stores, never, unknown>, "computeNextAt">[],
  stores: Stores,
  now: Date,
): Date | undefined => findEarliest(jobs.map((job) => job.computeNextAt(stores, now)));
