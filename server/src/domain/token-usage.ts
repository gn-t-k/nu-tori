// 提供元の呼び出しで実際に使ったトークン
export type TokenUsage = { inputTokens: number; outputTokens: number };

// プロンプトのキャッシュに書いた・読んだトークンも数えたもの。キャッシュの印を付ける呼び出し（返事）が返す。
// inputTokens はキャッシュの外の分（Anthropic の input_tokens）
export type CachedTokenUsage = TokenUsage & {
  cacheCreationInputTokens: number;
  cacheReadInputTokens: number;
};
