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

const updateAccountSettingsWriteSchema = z
  .object({
    id: writeId,
    type: z.literal("update_account_settings"),
    accountSettings: z.object({
      id: z.string().min(1).openapi({
        description:
          "端末で振ったアカウントの設定の ID。アカウント ID から名前空間を分けた UUID v5 で出す。サーバーは ID では探さず、アカウントに1件の記録として持つ",
      }),
      sendsUsageData: z.boolean(),
    }),
  })
  .openapi("UpdateAccountSettingsWrite");

export const syncWriteSchema = z
  .discriminatedUnion("type", [
    createWeightRecordWriteSchema,
    updateWeightRecordWriteSchema,
    updateAccountSettingsWriteSchema,
  ])
  .openapi("SyncWrite", {
    description: "アカウントの設定は、記録が無くても直す書き込みで送り、サーバーが無ければ作る",
  });
