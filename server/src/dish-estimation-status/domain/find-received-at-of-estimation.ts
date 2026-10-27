import type { EstimationSchedule } from "../../estimation/domain/estimation-schedule";
import { sortSchedulesNewestFirst } from "../../estimation/domain/sort-schedules-newest-first";

// 推定し直しの書き込みを受け取った時刻。その推定の予定から、見送りと保留でつながった前の予定を辿った、いちばん早い予定の時刻
export const findReceivedAtOfEstimation = (
  schedules: readonly EstimationSchedule[],
  estimationId: string,
): Date => {
  const own = schedules.find(
    (schedule) => "estimationId" in schedule && schedule.estimationId === estimationId,
  );
  if (own === undefined) {
    throw new Error(`推定を始めた料理の予定が無い: ${estimationId}`);
  }
  return findReceivedAtOfSchedule(schedules, own.scheduleId);
};

// 予定のもとの書き込みを受け取った時刻。その予定から、見送りと保留でつながった前の予定を辿った、いちばん早い予定の時刻。
// 見送りから作る次の日の予定と、保留から再開した予定は、前の予定とつながず別の予定なので、
// due_at の並びで、すぐ前が見送った・保留した予定である間だけ遡る
const findReceivedAtOfSchedule = (
  schedules: readonly EstimationSchedule[],
  scheduleId: string,
): Date => {
  const sorted = sortSchedulesNewestFirst(schedules);
  const ownIndex = sorted.findIndex((schedule) => schedule.scheduleId === scheduleId);
  const own = sorted[ownIndex];
  if (own === undefined) {
    throw new Error(`料理の予定が無い: ${scheduleId}`);
  }
  let receivedAt = own.dueAt;
  for (const previous of sorted.slice(ownIndex + 1)) {
    if (previous.progress !== "deferred" && previous.progress !== "held") {
      break;
    }
    receivedAt = previous.dueAt;
  }
  return receivedAt;
};
