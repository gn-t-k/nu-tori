import type { EstimationEvents } from "./estimation-events";

// 推定の出来事（予定・つなぎ・見送り・推定・試み・結果・完了・断念）を書く置き場。どれも INSERT だけで持つ。
// 推定の書き込みの口（writeEstimationEvents）にだけ渡し、ほかは読みだけの置き場で読む
export type EstimationEventWriteStore = {
  // 予定と一緒につなぎも書く
  insertMealSchedule: (schedule: EstimationEvents["schedule"]) => void;
  // 見送った予定は待っている予定から外れる
  insertDeferral: (deferral: EstimationEvents["deferral"]) => void;
  // 同じ予定から二度始めないことは、表の一意で守る
  insertEstimation: (estimation: EstimationEvents["estimation"]) => void;
  // 提供元を呼ぶ前に書く
  insertAttempt: (attempt: EstimationEvents["attempt"]) => void;
  insertAttemptResult: (attemptResult: EstimationEvents["attemptResult"]) => void;
  insertCompletion: (completion: EstimationEvents["completion"]) => void;
  insertAbandonment: (abandonment: EstimationEvents["abandonment"]) => void;
};
