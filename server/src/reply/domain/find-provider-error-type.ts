import { match } from "ts-pattern";
import type { ReplyAttemptConclusion } from "./reply-attempt";

// 試みで提供元が返したエラーの種類。提供元のエラーと 400 のときだけある
export const findProviderErrorType = (conclusion: ReplyAttemptConclusion): string | undefined =>
  match(conclusion)
    .with(
      { result: "succeeded" },
      { result: "timed_out" },
      { result: "invalid_response" },
      () => undefined,
    )
    .with({ result: "provider_error" }, { result: "bad_request" }, ({ errorType }) => errorType)
    .exhaustive();
