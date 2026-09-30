import type { WeightRecord } from "./weight-record";

// 端末から届く体重記録の書き込み
export type WeightRecordWrite = { id: string } & (
  | { type: "create_weight_record"; weightRecord: Omit<WeightRecord, "version"> }
  | { type: "update_weight_record"; weightRecord: Omit<WeightRecord, "imported"> }
  | { type: "source_deleted_weight_record"; weightRecordId: string }
);

// 書き込みの type の一覧。ドメインの種類の見分けと、受け口の見分けが、ここを使う
export const weightRecordWriteTypes: readonly string[] = [
  "create_weight_record",
  "update_weight_record",
  "source_deleted_weight_record",
];
