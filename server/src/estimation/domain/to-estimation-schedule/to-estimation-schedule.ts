import type { EstimationSchedule } from "../estimation-schedule";

// 予定の行と、その予定につながる出来事の行。無い出来事は null。置き場が表を結んで返す
export type EstimationScheduleEvents = {
  scheduleId: string;
  dueAt: Date;
  cancellation: string | null;
  deferral: string | null;
  hold: string | null;
  estimation: string | null;
  completion: "estimated" | "no_dishes" | null;
  abandonment: string | null;
};

// 予定の出来事から、予定の進み具合を出す。取り消し・見送り・保留した予定は推定を始めないので、推定の行より先に見る
export const toEstimationSchedule = ({
  scheduleId,
  dueAt,
  cancellation,
  deferral,
  hold,
  estimation,
  completion,
  abandonment,
}: EstimationScheduleEvents): EstimationSchedule => {
  const schedule = { scheduleId, dueAt };
  if (cancellation !== null) {
    return { ...schedule, progress: "cancelled" };
  }
  if (deferral !== null) {
    return { ...schedule, progress: "deferred" };
  }
  if (hold !== null) {
    return { ...schedule, progress: "held" };
  }
  if (estimation === null) {
    return { ...schedule, progress: "waiting" };
  }
  return {
    ...schedule,
    progress: completion ?? (abandonment === null ? "estimating" : "abandoned"),
    estimationId: estimation,
  };
};
