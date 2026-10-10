import type { RecordId } from "../../domain/record-id";
import type { TokenUsage } from "../../domain/token-usage";

// 試み1回の結果と、書くもの・送るもの。提供元の失敗と、読めない応答も試みの結果にする。
// usage は呼び出しで実際に使ったトークン（分からなければ undefined）。
// providerError は、Sentry に包まずに送る、提供元の応答のエラーの内容
export type ReplyAttemptOutcome =
  | { result: "succeeded"; body: string; mealIds: readonly RecordId[]; usage: TokenUsage }
  | { result: "timed_out"; usage: undefined }
  | { result: "invalid_response"; usage: TokenUsage | undefined }
  | {
      result: "provider_error" | "bad_request";
      usage: undefined;
      errorType: string;
      providerError: unknown;
    };
