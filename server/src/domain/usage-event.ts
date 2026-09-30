import type { CreateWeightRecordOutcome, UpdateWeightRecordOutcome } from "./sync-write-outcome";

export type UsageEvent =
  | {
      name: "sync_write_rejected";
      writeKind: "create";
      recordType: "weight_record";
      reason: Extract<CreateWeightRecordOutcome, { result: "rejected" }>["reason"];
    }
  | {
      name: "sync_write_rejected";
      writeKind: "update";
      recordType: "weight_record";
      reason: Extract<UpdateWeightRecordOutcome, { result: "rejected" }>["reason"];
    }
  | {
      name: "sync_pending_writes_reported";
      pendingWriteCount: number;
      oldestPendingWriteAgeSeconds: number;
    };
