import { computeScheduleStartsAt } from "./compute-schedule-starts-at";
import type { ScheduleStartStores } from "./schedule-start-stores";

// 待っている予定のうち、推定を始められるいちばん早い時刻。アラームの時刻に使う。写真を待たせている予定は、写真を待つ時間を過ぎる時刻。
// 写真が届いたら、写真の要求の入口で張り直すので、届いた時点で始められる
export const findEarliestScheduleStartsAt = (stores: ScheduleStartStores): Date | undefined =>
  stores.estimationSchedule
    .findWaitingSchedules(undefined)
    .map((schedule) => computeScheduleStartsAt(stores, schedule))
    .toSorted((a, b) => a.getTime() - b.getTime())[0];
