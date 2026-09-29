import { z } from "@hono/zod-openapi";

// Date が表せる範囲。これを超える時刻は、日付の計算で例外になる
const maximumTimestamp = 8.64e15;

const writeId = z.string().min(1).openapi({ description: "冪等の鍵" });

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
    id: writeId,
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
    id: writeId,
    type: z.literal("update_weight_record"),
    weightRecord: z.object({
      ...weightRecordFields,
      version: z.number().int(),
    }),
  })
  .openapi("UpdateWeightRecordWrite");

const sourceDeletedWeightRecordWriteSchema = z
  .object({
    id: writeId,
    type: z.literal("source_deleted_weight_record"),
    weightRecordId: z.string().min(1),
  })
  .openapi("SourceDeletedWeightRecordWrite");

export const syncWriteSchema = z
  .discriminatedUnion("type", [
    createWeightRecordWriteSchema,
    updateWeightRecordWriteSchema,
    sourceDeletedWeightRecordWriteSchema,
  ])
  .openapi("SyncWrite");
