// 読み分けの結果。決めかねたときと呼び出しの失敗は会話にするので、提供元の答え（ClassificationLabel）より狭い
export type SentTextClassification = "meal" | "conversation";
