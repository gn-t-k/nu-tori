import { estimationAttemptTimeLimitMs } from "../estimation-attempt-time-limit-ms";
import type { EstimationAttempt } from "../estimation-store";

// 続いている推定の、次に試みを書いて提供元を呼ぶ時刻。最後の試みの時刻と試みの数から出す。
// 待ちは 15 秒から試みごとに倍に広げる（6回やり直して約 16 分）。
// 結果の無い試みは呼び出し中かもしれないので、時間の上限が過ぎるまでは途中で止まったとみなさない
export const computeNextEstimationAttemptAt = (attempts: readonly EstimationAttempt[]): Date => {
  const last = attempts.at(-1);
  if (last === undefined) {
    throw new Error("試みの無い推定は無い（推定と最初の試みは同じトランザクションで書く）");
  }
  const waitMs = 15_000 * 2 ** (attempts.length - 1);
  return last.ended === undefined
    ? new Date(last.attemptedAt.getTime() + estimationAttemptTimeLimitMs + waitMs)
    : new Date(last.ended.endedAt.getTime() + waitMs);
};
