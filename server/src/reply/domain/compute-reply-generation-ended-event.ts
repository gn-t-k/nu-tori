import type { UsageEvent } from "../../domain/usage-event";
import { computeReplyFailureReason } from "./compute-reply-failure-reason";
import { findProviderErrorType } from "./find-provider-error-type";
import type { ReplyAttempt } from "./reply-attempt";

// 返事の生成ごとの出来事。本文は含めず、指し示した食事は数だけ
export const computeReplyGenerationEndedEvent = (ended: {
  final: { status: "replied"; referencedMealCount: number } | { status: "failed" };
  attempts: readonly ReplyAttempt[];
  requestedAt: Date;
  endedAt: Date;
}): UsageEvent => ({
  name: "reply_generation_ended",
  finalStatus: ended.final.status,
  failureReason:
    ended.final.status === "replied"
      ? undefined
      : computeReplyFailureReason(ended.attempts.at(-1)?.ended?.conclusion.result),
  retryCount: Math.max(ended.attempts.length - 1, 0),
  referencedMealCount: ended.final.status === "replied" ? ended.final.referencedMealCount : 0,
  secondsFromRequestedToEnded: Math.round(
    (ended.endedAt.getTime() - ended.requestedAt.getTime()) / 1000,
  ),
  providerErrorTypes: [
    ...new Set(
      ended.attempts.flatMap(({ ended: attemptEnded }) => {
        const errorType =
          attemptEnded === undefined ? undefined : findProviderErrorType(attemptEnded.conclusion);
        return errorType === undefined ? [] : [errorType];
      }),
    ),
  ],
});
