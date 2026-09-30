import { createWeightRecordWriteSchema } from "./create-weight-record-write-schema";
import { sourceDeletedWeightRecordWriteSchema } from "./source-deleted-weight-record-write-schema";
import { updateWeightRecordWriteSchema } from "./update-weight-record-write-schema";

// 体重記録の書き込みのスキーマ。型を保つため as const で並べる
export const weightRecordWriteSchemas = [
  createWeightRecordWriteSchema,
  updateWeightRecordWriteSchema,
  sourceDeletedWeightRecordWriteSchema,
] as const;
