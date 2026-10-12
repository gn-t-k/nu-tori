import { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import { recordIdSchema } from "../../domain/record-id";
import type { SyncWrite } from "../../domain/sync-write";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";
import type { WeightRecord } from "../domain/weight-record";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
const weightRecordRecordSchema = z
  .object({
    id: z.string(),
    weightKg: z.number(),
    measuredAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
    timeZone: z.string().openapi({ example: "Asia/Tokyo" }),
    version: z.number().int(),
    imported: z
      .object({
        sourceAppName: z.string(),
        sourceBundleId: z.string(),
        healthkitSampleUuid: z.string(),
        bodyFat: z.object({ percentage: z.number(), healthkitSampleUuid: z.string() }).optional(),
      })
      .optional()
      .openapi({ description: "ヘルスケアから取り込んだ記録だけに付く" }),
  })
  .openapi({
    description:
      "kind が weight_record の変更の record。消えたら kind が weight_record_deletion で record が空の変更が届く",
  });

// Date が表せる範囲。これを超える時刻は、日付の計算で例外になる
const maximumTimestamp = 8.64e15;

const weightRecordFields = {
  id: recordIdSchema,
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
          healthkitSampleUuid: recordIdSchema,
          bodyFat: z
            .object({
              percentage: z.number(),
              healthkitSampleUuid: recordIdSchema,
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
    weightRecordId: recordIdSchema,
  })
  .openapi("SourceDeletedWeightRecordWrite");

// 体重記録の書き込みのスキーマ。型を保つため as const で並べる
const weightRecordWriteSchemas = [
  createWeightRecordWriteSchema,
  updateWeightRecordWriteSchema,
  sourceDeletedWeightRecordWriteSchema,
] as const;

export const weightRecordHttpKind: HttpRecordKind<
  WeightRecord,
  (typeof weightRecordWriteSchemas)[number],
  typeof weightRecordRecordSchema
> = {
  writes: {
    schemas: weightRecordWriteSchemas,
    toWrite: (write) =>
      match(write)
        .with({ type: "create_weight_record" }, ({ id, weightRecord }): SyncWrite => ({
          id,
          type: "create_weight_record",
          weightRecord: {
            id: weightRecord.id,
            weightKg: weightRecord.weightKg,
            measuredAt: new Date(weightRecord.measuredAt),
            timeZone: weightRecord.timeZone,
            imported:
              weightRecord.imported === undefined
                ? undefined
                : {
                    sourceAppName: weightRecord.imported.sourceAppName,
                    sourceBundleId: weightRecord.imported.sourceBundleId,
                    healthkitSampleUuid: weightRecord.imported.healthkitSampleUuid,
                    bodyFat: weightRecord.imported.bodyFat,
                  },
          },
        }))
        .with({ type: "update_weight_record" }, ({ id, weightRecord }): SyncWrite => ({
          id,
          type: "update_weight_record",
          weightRecord: {
            id: weightRecord.id,
            weightKg: weightRecord.weightKg,
            measuredAt: new Date(weightRecord.measuredAt),
            timeZone: weightRecord.timeZone,
            version: weightRecord.version,
          },
        }))
        .with({ type: "source_deleted_weight_record" }, ({ id, weightRecordId }): SyncWrite => ({
          id,
          type: "source_deleted_weight_record",
          weightRecordId,
        }))
        .exhaustive(),
  },
  recordSchema: weightRecordRecordSchema,
  toRecord: (value) => ({
    id: value.id,
    weightKg: value.weightKg,
    measuredAt: value.measuredAt.getTime(),
    timeZone: value.timeZone,
    version: value.version,
    imported: value.imported,
  }),
};
