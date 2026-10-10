import { match } from "ts-pattern";
import { computeReplyFailureReason } from "../../reply/domain/compute-reply-failure-reason";
import type { SentTextReplyStatus } from "./sent-text-status";
import type { ReplyRequestProgress } from "./sent-text-status-store";

// 依頼から応答の状態を出す。終わっていない依頼があれば応答待ち、返事があれば返事あり（返事は文章に 0 か 1）。
// どちらも無ければ、回数切れと作れなかったのうち終えた時刻の新しい依頼で決める（設計判断 38）
export const computeSentTextReplyStatus = (
  requests: readonly ReplyRequestProgress[],
): SentTextReplyStatus => {
  if (requests.some(({ progress }) => progress === "waiting" || progress === "generating")) {
    return { type: "awaiting" };
  }
  if (requests.some(({ progress }) => progress === "replied")) {
    return { type: "replied" };
  }
  const lastEnded = requests
    .flatMap((request) =>
      request.progress === "halted" || request.progress === "abandoned" ? [request] : [],
    )
    .toSorted((a, b) => b.endedAt.getTime() - a.endedAt.getTime())[0];
  if (lastEnded === undefined) {
    return { type: "none" };
  }
  return match(lastEnded)
    .returnType<SentTextReplyStatus>()
    .with({ progress: "halted" }, () => ({ type: "halted" }))
    .with({ progress: "abandoned" }, ({ lastAttemptResult }) => ({
      type: "failed",
      reason: computeReplyFailureReason(lastAttemptResult),
    }))
    .exhaustive();
};
