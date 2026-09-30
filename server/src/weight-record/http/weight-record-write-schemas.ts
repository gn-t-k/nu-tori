import {
  createWeightRecordWriteSchema,
  sourceDeletedWeightRecordWriteSchema,
  updateWeightRecordWriteSchema,
} from "./weight-record-write-schema";

// 体重記録の書き込みのスキーマ。型を保つため as const で並べる
export const weightRecordWriteSchemas = [
  createWeightRecordWriteSchema,
  updateWeightRecordWriteSchema,
  sourceDeletedWeightRecordWriteSchema,
] as const;
