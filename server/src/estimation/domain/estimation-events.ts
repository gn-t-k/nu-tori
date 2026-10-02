import type { EstimationAttemptConclusion } from "./estimation-attempt-conclusion";

// 推定の出来事ごとの書く値。書く置き場（EstimationEventWriteStore）と推定の書き込み（EstimationWrites）で形をそろえる
export type EstimationEvents = {
  schedule: { id: string; mealId: string; dueAt: Date; countedOn: string };
  deferral: { scheduleId: string; deferredAt: Date };
  estimation: { id: string; scheduleId: string; startedAt: Date };
  attempt: { id: string; estimationId: string; attemptedAt: Date };
  attemptResult: { attemptId: string; endedAt: Date; conclusion: EstimationAttemptConclusion };
  completion: { estimationId: string; completedAt: Date; result: "estimated" | "no_dishes" };
  abandonment: { estimationId: string; abandonedAt: Date };
};
