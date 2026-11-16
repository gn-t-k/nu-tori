import type { RecordId } from "../../domain/record-id";
import type { WriteReceiptId } from "../../domain/sync-ledger/create-sync-ledger";
import type { SentText } from "./sent-text";
import type { SentTextClassification } from "./sent-text-classification";

export type SentTextStore = {
  find: (id: RecordId) => SentText | undefined;
  insert: (sentText: SentText) => void;
  // 送った時刻が from 以降の文章（送った時刻の順）
  findSentSince: (from: Date) => SentText[];
  // 読み分けを待っている文章（送った時刻の早い順）と、作る書き込みを受け取った時刻
  findUnclassified: () => { sentText: SentText; receivedAt: Date }[];
  insertClassification: (classification: {
    sentTextId: RecordId;
    classifiedAt: Date;
    result: SentTextClassification;
  }) => void;
  // 読み分けで提供元を呼ぶこと。呼ぶ前に書く。数える日は、呼ぶ前の時刻の、ユーザーの最新のタイムゾーンでの日
  insertClassificationCall: (call: {
    id: RecordId;
    sentTextId: RecordId;
    countedOn: string;
  }) => void;
  // 数える日 countedOn に、読み分けで提供元を呼んだ回数
  countClassificationCallsCountedOn: (countedOn: string) => number;
  // その文章から作った、いまある文章の食事
  findMealIds: (sentTextId: RecordId) => RecordId[];
  // 会話として送り直したこと。文章は控えの record_id。消した食事の削除の印も、同じ控えで書く
  insertConversationResend: (receiptId: WriteReceiptId) => void;
  insertConversationResendMealDeletion: (receiptId: WriteReceiptId, mealId: RecordId) => void;
  // 送り直したこと。文章は控えの record_id
  insertResend: (receiptId: WriteReceiptId) => void;
};
