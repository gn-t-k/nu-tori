import { R } from "@praha/byethrow";
import { type EstimationProvider, EstimationProviderError } from "../../domain/estimation-provider";

// 提供元の差し替えの口。Durable Object が推定のたびにここから提供元を得る。テストは偽物に差し替える。
// 本物（Anthropic の API）はまだつないでいないので、どの呼び出しも提供元のエラーで返す
export const createEstimationProvider = (_env: Env, _accountId: string): EstimationProvider => ({
  identifyDishes: async () => R.fail(new EstimationProviderError({ errorType: "not_connected" })),
  matchIngredients: async () => R.fail(new EstimationProviderError({ errorType: "not_connected" })),
});
