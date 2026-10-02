import type { EstimationAttemptConclusion } from "./estimation-attempt-conclusion";

// 推定の出来事（予定・つなぎ・見送り・推定・試み・結果・完了・断念）を書く置き場。どれも INSERT だけで持つ。
// 推定の書き込みの口（writeEstimationEvents）にだけ渡し、ほかは読みだけの置き場で読む
export type EstimationEventWriteStore = {
  // 予定とつなぎを書く
  insertMealSchedule: (schedule: {
    id: string;
    dueAt: Date;
    countedOn: string;
    mealId: string;
  }) => void;
  // 回数の上限で見送った事実を書く。見送った予定は待っている予定から外れる
  insertDeferral: (deferral: { scheduleId: string; deferredAt: Date }) => void;
  // 予定から推定を始める。同じ予定から二度始めないことは、表の一意で守る
  insertEstimation: (estimation: { id: string; scheduleId: string; startedAt: Date }) => void;
  // 提供元を呼ぶ前に書く
  insertAttempt: (attempt: { id: string; estimationId: string; attemptedAt: Date }) => void;
  insertAttemptResult: (attemptResult: {
    attemptId: string;
    endedAt: Date;
    conclusion: EstimationAttemptConclusion;
  }) => void;
  insertCompletion: (completion: {
    estimationId: string;
    completedAt: Date;
    result: "estimated" | "no_dishes";
  }) => void;
  insertAbandonment: (abandonment: { estimationId: string; abandonedAt: Date }) => void;
};
