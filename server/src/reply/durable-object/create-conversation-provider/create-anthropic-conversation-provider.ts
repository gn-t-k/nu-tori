import type Anthropic from "@anthropic-ai/sdk";
import { computeSha256Hex } from "../../../domain/compute-sha256-hex";
import type { ConversationProvider } from "../../domain/conversation-provider";
import { classifyWithHaiku } from "./classify-with-haiku";
import { generateReplyWithSonnet } from "./generate-reply-with-sonnet";

// Anthropic の API で読み分けと返事をする提供元。推定と同じワークスペース（環境ごとの API キー）から呼ぶ。
// 読み分けは Haiku 5.5（#423）、返事は Sonnet 5.5 を流す形で呼ぶ（#419 の「返事を作る」）
export const createAnthropicConversationProvider = (
  client: Anthropic,
  accountId: string,
): ConversationProvider => {
  // 提供元の濫用の検知に使う識別子。アカウント ID は元に戻せない形（SHA-256）にして渡す
  const userId = computeSha256Hex(accountId);
  return {
    classifySentText: async ({ body }) => classifyWithHaiku(client, await userId, body),
    generateReply: async (request, signal) =>
      generateReplyWithSonnet(client, await userId, request, signal),
  };
};
