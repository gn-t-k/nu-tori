import type { SyncWriteOutcome } from "./sync-write-outcome";

export type UsageEvent =
  | {
      name: "sync_write_rejected";
      writeKind: "create" | "update";
      recordType: "weight_record";
      reason: Extract<SyncWriteOutcome, { result: "rejected" }>["reason"];
    }
  | {
      name: "sync_pending_writes_reported";
      pendingWriteCount: number;
      oldestPendingWriteAgeSeconds: number;
    };
