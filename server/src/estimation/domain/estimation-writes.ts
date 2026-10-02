import type { EstimationAttemptConclusion } from "./estimation-attempt-conclusion";

// 推定の書き込み。推定の書き込みの口（writeEstimationEvents）が、書く関数にだけ渡す。
// 推定の状態を変え得る書き込みは対象の食事を受け取り、口はその食事の状態を書く前とあとで比べる
export type EstimationWrites = {
  // 写真がそろった食事を、推定の予定に入れる
  scheduleMeal: (schedule: { id: string; mealId: string; dueAt: Date; countedOn: string }) => void;
  // 待っている予定を、1日の上限で見送り、次の日の予定を足す
  deferToNextDay: (deferral: {
    scheduleId: string;
    mealId: string;
    deferredAt: Date;
    nextSchedule: { id: string; dueAt: Date; countedOn: string };
  }) => void;
  // 予定から推定を始める
  beginEstimation: (estimation: {
    id: string;
    scheduleId: string;
    mealId: string;
    startedAt: Date;
  }) => void;
  // 試みとその結果は、推定の状態を変えない
  beginAttempt: (attempt: { id: string; estimationId: string; attemptedAt: Date }) => void;
  recordAttemptResult: (attemptResult: {
    attemptId: string;
    endedAt: Date;
    conclusion: EstimationAttemptConclusion;
  }) => void;
  // 推定を推定済みか料理なしで終える
  complete: (completion: {
    estimationId: string;
    mealId: string;
    completedAt: Date;
    result: "estimated" | "no_dishes";
  }) => void;
  // 推定をあきらめる
  abandon: (abandonment: { estimationId: string; mealId: string; abandonedAt: Date }) => void;
};
