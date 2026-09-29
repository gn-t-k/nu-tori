import { z } from "@hono/zod-openapi";

// Date が表せる範囲。これを超える時刻は、日付の計算で例外になる
const maximumTimestamp = 8.64e15;

const writeId = z.string().min(1).openapi({ description: "書き込みごとに端末で振る ID。冪等の鍵" });

const weightRecordFields = {
  id: z.string().min(1).openapi({ description: "端末で振った体重記録の ID" }),
  weightKg: z.number(),
  measuredAt: z
    .number()
    .int()
    .min(-maximumTimestamp)
    .max(maximumTimestamp)
    .openapi({ description: "測った時刻。UNIX 時刻のミリ秒（UTC）" }),
  timeZone: z.string().openapi({
    description: "記録したときの IANA のタイムゾーン名。読めない名前の書き込みは受け付けない",
    example: "Asia/Tokyo",
  }),
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
              percentage: z.number().openapi({ description: "% の値（25.0）" }),
              healthkitSampleUuid: z.string().min(1),
            })
            .optional(),
        })
        .optional()
        .openapi({ description: "ヘルスケアから取り込んだ記録だけが持つ" }),
    }),
  })
  .openapi("CreateWeightRecordWrite");

const updateWeightRecordWriteSchema = z
  .object({
    id: writeId,
    type: z.literal("update_weight_record"),
    weightRecord: z.object({
      ...weightRecordFields,
      version: z.number().int().openapi({
        description: "直したあとの版。2 以上。届いた版と今の版 + 1 の大きいほうに決め直す",
      }),
    }),
  })
  .openapi("UpdateWeightRecordWrite");

export const syncWriteSchema = z
  .discriminatedUnion("type", [createWeightRecordWriteSchema, updateWeightRecordWriteSchema])
  .openapi("SyncWrite", { description: "作る書き込みと直す書き込み。type ごとに中身が違う" });
