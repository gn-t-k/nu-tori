import type { TokenUsage } from "../../domain/token-usage";

// 試みの呼び出し（①・②）ごとに実際に使ったトークン。呼ばなかった・使った分が分からない呼び出しは undefined
export type EstimationAttemptUsage = {
  identifyDishes: TokenUsage | undefined;
  matchIngredients: TokenUsage | undefined;
};
