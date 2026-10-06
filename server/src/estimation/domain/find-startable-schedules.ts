import { computeScheduleStartsAt } from "./compute-schedule-starts-at";
import type { WaitingSchedule } from "./estimation-schedule-store";
import type { ScheduleStartStores } from "./schedule-start-stores";

// 待っている予定のうち、いま推定を始められるもの（早い順）。料理が対象の予定は、食事の写真がまだすべては届いていないあいだ、
// 写真を待つ時間を過ぎるまで待たせる（推定も見送りもせず、数えない）
export const findStartableSchedules = (stores: ScheduleStartStores, now: Date): WaitingSchedule[] =>
  stores.estimationSchedule
    .findWaitingSchedules(now)
    .filter((schedule) => computeScheduleStartsAt(stores, schedule).getTime() <= now.getTime());
