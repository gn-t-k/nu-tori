import type { EstimatedDish } from "./estimated-dish";
import type { EstimationAttemptUsage } from "./estimation-attempt-usage";

// 試み1回の結果と、書くもの・送るもの。提供元の失敗と、確かめに通らない応答も試みの結果にする。
// failedStage は、アラームの呼び出しごとのログに出す失敗した呼び出し。
// providerError は、Sentry に包まずに送る、提供元の応答のエラーの内容
export type EstimationAttemptOutcome =
  | { result: "succeeded"; dishes: EstimatedDish[]; usage: EstimationAttemptUsage }
  | {
      result: "timed_out" | "invalid_response";
      failedStage: "identify_dishes" | "match_ingredients";
      usage: EstimationAttemptUsage;
    }
  | {
      result: "provider_error" | "bad_request";
      failedStage: "identify_dishes" | "match_ingredients";
      usage: EstimationAttemptUsage;
      errorType: string;
      providerError: unknown;
    };
