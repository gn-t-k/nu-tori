import { computeNextAttemptAt } from "../../../domain/compute-next-attempt-at";
import { estimationAttemptTimeLimitMs } from "../estimation-attempt-time-limit-ms";
import type { EstimationAttempt } from "../estimation-store";

// 続いている推定の、次に試みを書いて提供元を呼ぶ時刻。待ちの広げ方は返事の生成と同じ（computeNextAttemptAt）
export const computeNextEstimationAttemptAt = (attempts: readonly EstimationAttempt[]): Date =>
  computeNextAttemptAt(attempts, estimationAttemptTimeLimitMs);
