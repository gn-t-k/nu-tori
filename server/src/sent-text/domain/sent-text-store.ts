import type { RecordId } from "../../domain/record-id";
import type { SentText } from "./sent-text";

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
    result: "meal" | "conversation";
  }) => void;
};
