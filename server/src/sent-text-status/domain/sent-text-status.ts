// 送った文章の状態。行を持たず、読み分けと返事の流れの出来事から出す（#419 の「同期」）
export type SentTextStatus = {
  // 読み分けの今の結果。pending は読み分けを待っている
  classification: "pending" | "meal" | "conversation";
  reply: SentTextReplyStatus;
};

// 応答の状態。返事の依頼が無い文章（読み分け待ち・食事と読み分けた）は none
export type SentTextReplyStatus =
  | { type: "none" }
  // 依頼が回数切れでも、作れなかったでも、返事ありでもない（生成を待っている・作っている・やり直しを待っている）
  | { type: "awaiting" }
  | { type: "replied" }
  | { type: "halted" }
  | { type: "failed"; reason: ReplyFailureReason };

// 作れなかった理由。最後の試みの結果が 400 なら bad_request、ほかはやり直しを使い切った
export type ReplyFailureReason = "retries_exhausted" | "bad_request";
