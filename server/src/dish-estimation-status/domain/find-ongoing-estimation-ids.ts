import type { EstimationSchedule } from "../../estimation/domain/estimation-schedule";

// 料理の推定を始めて、まだ完了も断念もしていない推定
export const findOngoingEstimationIds = (schedules: readonly EstimationSchedule[]): string[] =>
  schedules.flatMap((schedule) =>
    schedule.progress === "estimating" ? [schedule.estimationId] : [],
  );
