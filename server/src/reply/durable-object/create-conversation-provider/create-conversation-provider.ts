import Anthropic from "@anthropic-ai/sdk";
import type { ConversationProvider } from "../../domain/conversation-provider";
import { createAnthropicConversationProvider } from "./create-anthropic-conversation-provider";

// 提供元の差し替えの口。Durable Object が読み分けと返事のたびにここから提供元を得る。テストは同じフォルダの mock で偽物に差し替える。
// どのモデルで読み分けるかはこの層が決める（#419 の「読み分け」）。今は推定と同じ Anthropic のワークスペースの、読み分けは Haiku 5.5（#423）、返事は Sonnet 5.5
export const createConversationProvider = (env: Env, accountId: string): ConversationProvider =>
  createAnthropicConversationProvider(
    // 読み分けはやり直さず、失敗は会話にする。返事の再試行はドメイン層が持つ。どちらも SDK の再試行は切る
    new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, maxRetries: 0 }),
    accountId,
  );
