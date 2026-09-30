import type { RecordType } from "./record-type";
import type { RejectionReason } from "./rejection-reason";
import type { WriteKind } from "./sync-ledger/write-kind";

export type UsageEvent =
  | {
      name: "sync_write_rejected";
      writeKind: WriteKind;
      recordType: RecordType;
      reason: RejectionReason;
    }
  | {
      name: "sync_pending_writes_reported";
      pendingWriteCount: number;
      oldestPendingWriteAgeSeconds: number;
    };
