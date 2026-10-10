import type { R } from "@praha/byethrow";
import type { TokenUsage } from "../../estimation/domain/estimation-provider";
import type { ConversationProviderError } from "./conversation-provider-error";

// 送った文章を読む提供元（LLM）。読み分けと返事の両方を受け持つ（返事は #429 で足す）。
// どのモデルで読み分けるかは、基盤に固有の層が決める（#419 の「読み分け」）。応答は残さず、結果だけをドメイン層が書く
export type ConversationProvider = {
  // 食べた・飲んだものを伝えていれば meal、ほかは conversation、確信が持てなければ unsure を返す
  classifySentText: (request: {
    body: string;
  }) => R.ResultAsync<ClassificationReply, ConversationProviderError>;
};

export type ClassificationReply = {
  label: ClassificationLabel;
  // 呼び出しで実際に使ったトークン
  usage: TokenUsage;
};

export type ClassificationLabel = "meal" | "conversation" | "unsure";
