import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { Notice, NoticeResponse } from "./notice";

export type NoticeStore = {
  find: (id: string) => Notice | undefined;
  insert: (notice: Omit<Notice, "response">) => void;
  // 答えは答える書き込みの控えを指すので、控えの ID を受け取る
  insertResponse: (receiptId: WriteReceiptId, noticeId: string, response: NoticeResponse) => void;
};
