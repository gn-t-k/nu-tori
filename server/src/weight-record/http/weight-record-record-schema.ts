import { z } from "@hono/zod-openapi";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
export const weightRecordRecordSchema = z
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
