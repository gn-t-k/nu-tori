import type { RecordId } from "../../domain/record-id";
import type { ReplyFailureReason } from "../../sent-text-status/domain/sent-text-status";

// 見守る要求で流す出来事。返事の ID（返事の生成の ID。試みをまたいで同じ）、できた分、流した分を捨てる知らせと、
// 閉じる前に1つだけ送る結果（返事あり・食事と読み分けた・回数切れ・作れなかった）
export type ReplyStreamEvent =
  | { type: "reply_started"; replyId: RecordId }
  | { type: "text_delta"; text: string }
  // 試みが流している途中で失敗した。次の試みで初めから流し直す
  | { type: "text_discarded" }
  | ReplyStreamEnding;

// 閉じる前に送る結果
export type ReplyStreamEnding =
  | { type: "replied"; replyId: RecordId }
  | { type: "classified_as_meal" }
  | { type: "reply_halted" }
  | { type: "reply_failed"; failureReason: ReplyFailureReason };
