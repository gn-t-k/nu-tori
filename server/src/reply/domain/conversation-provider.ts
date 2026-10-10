import type { R } from "@praha/byethrow";
import type { RecordId } from "../../domain/record-id";
import type { TokenUsage } from "../../estimation/domain/estimation-provider";
import type { ConversationProviderBadRequestError } from "./conversation-provider-bad-request-error";
import type { ConversationProviderError } from "./conversation-provider-error";
import type { ConversationProviderInvalidResponseError } from "./conversation-provider-invalid-response-error";
import type { ConversationProviderTimedOutError } from "./conversation-provider-timed-out-error";
import type { ReplyContext } from "./reply-context";

// 送った文章を読む提供元（LLM）。読み分けと返事の両方を受け持つ。
// どのモデルで読み分けるかは、基盤に固有の層が決める（#419 の「読み分け」）。応答は残さず、結果だけをドメイン層が書く
export type ConversationProvider = {
  // 食べた・飲んだものを伝えていれば meal、ほかは conversation、確信が持てなければ unsure を返す
  classifySentText: (request: {
    body: string;
  }) => R.ResultAsync<ClassificationReply, ConversationProviderError>;
  // 文脈を渡して返事を作らせる。文脈を文の塊にして指示と並べるのは提供元が受け持つ。
  // signal は試みの時間の上限で切れる。提供元は切れたら ConversationProviderTimedOutError で返す。
  // 出力の上限で切れた・決めた形に読めない応答は ConversationProviderInvalidResponseError で返す
  generateReply: (
    request: { context: ReplyContext },
    signal: AbortSignal,
  ) => R.ResultAsync<
    GeneratedReply,
    | ConversationProviderError
    | ConversationProviderBadRequestError
    | ConversationProviderTimedOutError
    | ConversationProviderInvalidResponseError
  >;
};

export type ClassificationReply = {
  label: ClassificationLabel;
  // 呼び出しで実際に使ったトークン
  usage: TokenUsage;
};

export type ClassificationLabel = "meal" | "conversation" | "unsure";

export type GeneratedReply = {
  body: string;
  // 指し示す食事の ID。並びが返事の中の並び。文脈で ID を付けた食事のほかを返したら、ドメイン層が読めない応答にする
  mealIds: readonly RecordId[];
  // 呼び出しで実際に使ったトークン
  usage: TokenUsage;
};
