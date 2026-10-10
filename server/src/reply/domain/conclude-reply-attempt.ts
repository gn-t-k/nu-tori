import { match } from "ts-pattern";
import type { ReplyAttemptConclusion } from "./reply-attempt";
import type { ReplyAttemptOutcome } from "./reply-attempt-outcome";

// 試みの結果を、表に書きログに出すもの（返事の本文、トークン、提供元の応答のエラーを除く）と、Sentry に包まずに送る提供元の応答のエラー（提供元のエラーと 400）に分ける
export const concludeReplyAttempt = (
  outcome: ReplyAttemptOutcome,
): { conclusion: ReplyAttemptConclusion; providerErrors: unknown[] } =>
  match(outcome)
    .returnType<{ conclusion: ReplyAttemptConclusion; providerErrors: unknown[] }>()
    .with(
      { result: "succeeded" },
      { result: "timed_out" },
      { result: "invalid_response" },
      ({ result }) => ({ conclusion: { result }, providerErrors: [] }),
    )
    .with(
      { result: "provider_error" },
      { result: "bad_request" },
      ({ result, errorType, providerError }) => ({
        conclusion: { result, errorType },
        providerErrors: [providerError],
      }),
    )
    .exhaustive();
