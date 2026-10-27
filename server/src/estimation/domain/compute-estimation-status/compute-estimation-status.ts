import { match } from "ts-pattern";
import type { EstimationSchedule } from "../estimation-schedule";
import type { ScheduledEstimationStatus } from "../scheduled-estimation-status";
import { sortSchedulesNewestFirst } from "../sort-schedules-newest-first";

// 見送りから作る次の日の予定は、見送りと同じトランザクションで足し、時刻が次の日の 0:00 なので、見送った予定のすぐあとに並ぶ。
// 保留から再開した予定と、名前を直した・料理を足した予定は、見送りから作らないので、すぐ前の予定は見送りではない。
// 今の時刻で決めると、出来事を書かずに 0:00 で状態が変わり、変更の並びに載らないので、出来事だけで決める
export const computeEstimationStatus = (
  schedules: readonly EstimationSchedule[],
): ScheduledEstimationStatus | undefined => {
  const [newest, previous] = sortSchedulesNewestFirst(schedules.filter(isActive));
  if (newest === undefined) {
    return undefined;
  }
  return match(newest.progress)
    .returnType<ScheduledEstimationStatus>()
    .with("waiting", () =>
      previous?.progress === "deferred" ? "deferred_to_next_day" : "estimating",
    )
    .with("deferred", () => "deferred_to_next_day")
    .with("held", () => "awaiting_subscription")
    .with("estimating", () => "estimating")
    .with("estimated", () => "estimated")
    .with("no_dishes", () => "no_dishes")
    .with("abandoned", () => "failed")
    .exhaustive();
};

const isActive = (
  schedule: EstimationSchedule,
): schedule is Exclude<EstimationSchedule, { progress: "cancelled" }> =>
  schedule.progress !== "cancelled";
