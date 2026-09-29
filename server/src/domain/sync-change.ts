import type { WeightRecord } from "./weight-record";

export type SyncChange = { sequence: number } & (
  | { type: "weight_record"; weightRecord: WeightRecord }
  | { type: "weight_record_deletion"; recordId: string }
);
