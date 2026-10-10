import type { EstimatedDish } from "./estimated-dish";
import type { EstimationAttemptUsage } from "./estimation-attempt-usage";

// 試み1回の結果と、書くもの・送るもの。提供元の失敗と、確かめに通らない応答も試みの結果にする。
// failedStage は、アラームの呼び出しごとのログに出す失敗した呼び出し。
// providerError は、Sentry に包まずに送る、提供元の応答のエラーの内容
export type EstimationAttemptOutcome =
  | {
      result: "succeeded";
      // 文章の食事では、1つ目の食事の料理
      dishes: EstimatedDish[];
      // 文章の食事の推定で、食事が1つ以上返ったときだけある
      writtenMeals: EstimatedWrittenMeals | undefined;
      usage: EstimationAttemptUsage;
    }
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

// 文章の食事の推定が決めた、1つ目の食事の時刻と、時刻の違う2つめ以降の食事。時刻は範囲に収めたもの
export type EstimatedWrittenMeals = {
  eatenAt: Date;
  laterMeals: { eatenAt: Date; dishes: EstimatedDish[] }[];
};
