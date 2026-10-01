import type Anthropic from "@anthropic-ai/sdk";
import type { EstimationProvider } from "../../domain/estimation-provider";
import { identifyDishes } from "./identify-dishes";
import { matchIngredients } from "./match-ingredients";

// Anthropic の API で ①（写真）と ② を呼ぶ提供元。提供元の応答は残さない
export const createAnthropicEstimationProvider = (
  client: Anthropic,
  accountId: string,
): EstimationProvider => {
  // 提供元の濫用の検知に使う識別子。アカウント ID は元に戻せない形（SHA-256）にして渡す
  const userId = hashAccountId(accountId);
  return {
    identifyDishes: async (request, signal) =>
      identifyDishes(client, await userId, request, signal),
    matchIngredients: async (request, signal) =>
      matchIngredients(client, await userId, request, signal),
  };
};

const hashAccountId = async (accountId: string): Promise<string> => {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(accountId)),
  );
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
};
