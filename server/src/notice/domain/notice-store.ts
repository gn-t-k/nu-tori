import type { RecordId } from "../../domain/record-id";
import type { WriteReceiptId } from "../../domain/sync-ledger/create-sync-ledger";
import type { IssuedNotice, Notice, NoticeResponse } from "./notice";

export type NoticeStore = {
  find: (id: RecordId) => Notice | undefined;
  insert: (notice: IssuedNotice) => void;
  // 答えは答える書き込みの控えを指すので、控えの ID を受け取る
  insertResponse: (receiptId: WriteReceiptId, noticeId: RecordId, response: NoticeResponse) => void;
};
