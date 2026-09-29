import type { WeightRecord } from "./weight-record";

export type SyncWrite = { id: string } & (
  | { type: "create_weight_record"; weightRecord: Omit<WeightRecord, "version"> }
  | { type: "update_weight_record"; weightRecord: Omit<WeightRecord, "imported"> }
  | { type: "source_deleted_weight_record"; weightRecordId: string }
);
