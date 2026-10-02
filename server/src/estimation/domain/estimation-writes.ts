import type { EstimationEvents } from "./estimation-events";

// 推定の書き込み。推定の書き込みの口（writeEstimationEvents）が、書く関数にだけ渡す。
// 推定の状態を変え得る書き込みは対象の食事を受け取り、口はその食事の状態を書く前とあとで比べる
export type EstimationWrites = {
  scheduleMeal: (schedule: EstimationEvents["schedule"]) => void;
  // 1日の上限で見送るときは、次の日の予定も同じ書き込みで足す
  deferToNextDay: (
    deferral: EstimationEvents["deferral"] & {
      mealId: string;
      nextSchedule: Omit<EstimationEvents["schedule"], "mealId">;
    },
  ) => void;
  beginEstimation: (estimation: EstimationEvents["estimation"] & { mealId: string }) => void;
  // 試みとその結果は、推定の状態を変えない
  beginAttempt: (attempt: EstimationEvents["attempt"]) => void;
  recordAttemptResult: (attemptResult: EstimationEvents["attemptResult"]) => void;
  complete: (completion: EstimationEvents["completion"] & { mealId: string }) => void;
  abandon: (abandonment: EstimationEvents["abandonment"] & { mealId: string }) => void;
};
