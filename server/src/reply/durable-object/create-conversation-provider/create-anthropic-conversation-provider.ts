import type Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import type { ConversationProvider } from "../../domain/conversation-provider";
import { ConversationProviderError } from "../../domain/conversation-provider-error";
import { classifyWithHaiku } from "./classify-with-haiku";

// Anthropic の API で読み分ける提供元。推定と同じワークスペース（環境ごとの API キー）から呼ぶ（#423 で Haiku 5.5 に決めた）。
// 返事は #433 でつなぐ。つなぐまでは提供元のエラーとしてやり直し、使い切ると作れなかったになる
export const createAnthropicConversationProvider = (
  client: Anthropic,
  accountId: string,
): ConversationProvider => {
  // 提供元の濫用の検知に使う識別子。アカウント ID は元に戻せない形（SHA-256）にして渡す
  const userId = hashAccountId(accountId);
  return {
    classifySentText: async ({ body }) => classifyWithHaiku(client, await userId, body),
    generateReply: async () =>
      R.fail(new ConversationProviderError({ errorType: "not_connected" })),
  };
};

const hashAccountId = async (accountId: string): Promise<string> => {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(accountId)),
  );
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
};
