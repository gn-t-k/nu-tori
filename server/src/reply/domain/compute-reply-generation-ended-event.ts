import { match, P } from "ts-pattern";
import type { UsageEvent } from "../../domain/usage-event";
import type { ReplyAttempt, ReplyAttemptConclusion } from "./reply-attempt";

// 返事の生成ごとの出来事。本文は含めず、指し示した食事は数だけ
export const computeReplyGenerationEndedEvent = (ended: {
  final: { status: "replied"; referencedMealCount: number } | { status: "failed" };
  attempts: readonly ReplyAttempt[];
  requestedAt: Date;
  endedAt: Date;
}): UsageEvent => ({
  name: "reply_generation_ended",
  finalStatus: ended.final.status,
  // 最後の試みが 400 なら 400、ほかはやり直しを使い切った（送った文章の状態の理由と同じ決まり）
  failureReason:
    ended.final.status === "replied"
      ? undefined
      : ended.attempts.at(-1)?.ended?.conclusion.result === "bad_request"
        ? "bad_request"
        : "retries_exhausted",
  retryCount: Math.max(ended.attempts.length - 1, 0),
  referencedMealCount: ended.final.status === "replied" ? ended.final.referencedMealCount : 0,
  secondsFromRequestedToEnded: Math.round(
    (ended.endedAt.getTime() - ended.requestedAt.getTime()) / 1000,
  ),
  providerErrorTypes: [
    ...new Set(
      ended.attempts.flatMap(({ ended: attemptEnded }) =>
        attemptEnded === undefined ? [] : toErrorTypes(attemptEnded.conclusion),
      ),
    ),
  ],
});

const toErrorTypes = (conclusion: ReplyAttemptConclusion): string[] =>
  match(conclusion)
    .returnType<string[]>()
    .with({ result: P.union("succeeded", "timed_out", "invalid_response") }, () => [])
    .with({ result: P.union("provider_error", "bad_request") }, ({ errorType }) => [errorType])
    .exhaustive();
