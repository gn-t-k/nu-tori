import type { RecordId } from "../../domain/record-id";
import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { SentText } from "./sent-text";

export type SentTextStore = {
  find: (id: RecordId) => SentText | undefined;
  insert: (sentText: SentText) => void;
  // 読み分けを待っている文章（送った時刻の早い順）と、作る書き込みを受け取った時刻
  findUnclassified: () => { sentText: SentText; receivedAt: Date }[];
  insertClassification: (classification: {
    sentTextId: RecordId;
    classifiedAt: Date;
    result: "meal" | "conversation";
  }) => void;
  // その文章から作った、いまある文章の食事
  findMealIds: (sentTextId: RecordId) => RecordId[];
  // 会話として送り直したこと。文章は控えの record_id。消した食事の削除の印も、同じ控えで書く
  insertConversationResend: (receiptId: WriteReceiptId) => void;
  insertConversationResendMealDeletion: (receiptId: WriteReceiptId, mealId: RecordId) => void;
};
