import type { RejectionReason } from "./rejection-reason";

export type SyncWriteOutcome =
  | { result: "applied" | "ignored_duplicate" | "ignored_tombstone" | "kept_corrected" }
  | {
      result: "rejected";
      reason: RejectionReason;
    };
