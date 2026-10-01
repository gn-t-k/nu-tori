import { z } from "@hono/zod-openapi";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";

// Date が表せる範囲。これを超える時刻は、日付の計算で例外になる
const maximumTimestamp = 8.64e15;

const weightRecordFields = {
  id: z.string().min(1),
  weightKg: z.number(),
  measuredAt: z
    .number()
    .int()
    .min(-maximumTimestamp)
    .max(maximumTimestamp)
    .openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
  timeZone: z.string().openapi({ example: "Asia/Tokyo" }),
};

const createWeightRecordWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("create_weight_record"),
    weightRecord: z.object({
      ...weightRecordFields,
      imported: z
        .object({
          sourceAppName: z.string(),
          sourceBundleId: z.string(),
          healthkitSampleUuid: z.string().min(1),
          bodyFat: z
            .object({
              percentage: z.number(),
              healthkitSampleUuid: z.string().min(1),
            })
            .optional(),
        })
        .optional(),
    }),
  })
  .openapi("CreateWeightRecordWrite");

const updateWeightRecordWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("update_weight_record"),
    weightRecord: z.object({
      ...weightRecordFields,
      version: z.number().int(),
    }),
  })
  .openapi("UpdateWeightRecordWrite");

const sourceDeletedWeightRecordWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("source_deleted_weight_record"),
    weightRecordId: z.string().min(1),
  })
  .openapi("SourceDeletedWeightRecordWrite");

// 体重記録の書き込みのスキーマ。型を保つため as const で並べる
export const weightRecordWriteSchemas = [
  createWeightRecordWriteSchema,
  updateWeightRecordWriteSchema,
  sourceDeletedWeightRecordWriteSchema,
] as const;
