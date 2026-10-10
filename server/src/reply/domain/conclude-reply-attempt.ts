import { match } from "ts-pattern";
import type { ReplyAttemptConclusion } from "./reply-attempt";
import type { ReplyAttemptOutcome } from "./reply-attempt-outcome";

// 試みの結果のうち、表に書き、ログに出すもの（返事の本文、トークン、提供元の応答のエラーを除く）
export const concludeReplyAttempt = (outcome: ReplyAttemptOutcome): ReplyAttemptConclusion =>
  match(outcome)
    .returnType<ReplyAttemptConclusion>()
    .with(
      { result: "succeeded" },
      { result: "timed_out" },
      { result: "invalid_response" },
      ({ result }) => ({ result }),
    )
    .with({ result: "provider_error" }, { result: "bad_request" }, ({ result, errorType }) => ({
      result,
      errorType,
    }))
    .exhaustive();
