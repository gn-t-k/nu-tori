// 提供元の呼び出しで実際に使ったトークン。キャッシュの印を付けない呼び出し（推定・読み分け）が返す
export type TokenUsage = { type: "uncached"; inputTokens: number; outputTokens: number };

// プロンプトのキャッシュに書いた・読んだトークンも数えたもの。キャッシュの印を付ける呼び出し（返事）が返す。
// inputTokens はキャッシュの外の分（Anthropic の input_tokens）
export type CachedTokenUsage = {
  type: "cached";
  inputTokens: number;
  outputTokens: number;
  cacheCreationInputTokens: number;
  cacheReadInputTokens: number;
};
