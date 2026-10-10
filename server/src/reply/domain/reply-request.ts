import type { RecordId } from "../../domain/record-id";
import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";

// 返事の依頼。依頼ときっかけのサブセットは、返事の書き込みの口（writeReplyEvents）の request で一緒に書く
export type ReplyRequest = {
  id: string;
  sentTextId: RecordId;
  // 依頼を作った時点の、ユーザーの最新のタイムゾーンでの日（読めなければ送った文章のタイムゾーン）
  countedOn: string;
  // きっかけ。送り直したは、その書き込みを足すチケット（#430）で、控えの ID を持つ型として足す
  trigger:
    | { type: "classification" }
    // 会話として送り直す書き込みの控え（sent_text_conversation_resends を指す）
    | { type: "conversation_resend"; receiptId: WriteReceiptId };
};
