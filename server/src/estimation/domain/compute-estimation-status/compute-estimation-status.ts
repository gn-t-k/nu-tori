import { match } from "ts-pattern";
import type { EstimationSchedule } from "../estimation-schedule";
import { sortSchedulesNewestFirst } from "../sort-schedules-newest-first";

// 予定から出す推定の状態。食事の推定の状態から「写真を待っている」を除いたもので、料理ごとの推定の状態と同じ
export type ScheduledEstimationStatus =
  | "estimating"
  | "deferred_to_next_day"
  | "awaiting_subscription"
  | "estimated"
  | "no_dishes"
  | "failed";

// 食事か料理につながる推定の予定から、推定の状態を出す。取り消していない予定のうち、いちばん新しい予定とその出来事で決める。
// まだ推定を始めていない予定は、すぐ前の予定が見送りなら翌日に推定、ほかは推定中。見送りから作る次の日の予定は、見送りと同じ
// トランザクションで足し、時刻が次の日の 0:00 なので見送った予定のすぐあとに並ぶ。保留から再開した予定と、名前を直した・料理を
// 足した予定は、すぐ前が見送りではない。今の時刻で決めないので、出来事を書かないかぎり状態は変わらない。予定が無ければ undefined
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
