import type Anthropic from "@anthropic-ai/sdk";
import { computeSha256Hex } from "../../../domain/compute-sha256-hex";
import type { EstimationProvider } from "../../domain/estimation-provider";
import { identifyDishes } from "./identify-dishes";
import { identifyWrittenMeals } from "./identify-written-meals";
import { matchIngredients } from "./match-ingredients";

// Anthropic の API で ①（写真か送った文章）と ② を呼ぶ提供元。提供元の応答は残さない
export const createAnthropicEstimationProvider = (
  client: Anthropic,
  accountId: string,
): EstimationProvider => {
  // 提供元の濫用の検知に使う識別子。アカウント ID は元に戻せない形（SHA-256）にして渡す
  const userId = computeSha256Hex(accountId);
  return {
    identifyDishes: async (request, signal) =>
      identifyDishes(client, await userId, request, signal),
    identifyWrittenMeals: async (request, signal) =>
      identifyWrittenMeals(client, await userId, request, signal),
    matchIngredients: async (request, signal) =>
      matchIngredients(client, await userId, request, signal),
  };
};
