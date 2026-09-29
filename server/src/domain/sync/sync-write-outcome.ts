export type SyncWriteOutcome =
  | { result: "applied" | "ignored_duplicate" }
  | {
      result: "rejected";
      reason:
        | "out_of_range"
        | "invalid_time_zone"
        | "version_too_low"
        | "record_not_found"
        | "record_before_started_on";
    };
