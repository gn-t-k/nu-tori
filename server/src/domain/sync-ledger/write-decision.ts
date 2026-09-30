import type { SyncWriteOutcome } from "../sync-write-outcome";
import type { WriteKind } from "./write-kind";
import type { WriteReceiptId } from "./write-receipt-id";

export type WriteDecision = {
  writeKind: WriteKind;
  // 書き込みの控えに載せる記録の ID
  recordId: string;
  outcome: SyncWriteOutcome;
  // 変更の並びに載せる記録の ID。載せないとき undefined
  changedRecordId: string | undefined;
  // 帳簿が控えを書いたあとに呼ぶ。控えの ID は帳簿しか作れないので、控えより先に自分の行を書けない
  commit: (receiptId: WriteReceiptId) => void;
};
