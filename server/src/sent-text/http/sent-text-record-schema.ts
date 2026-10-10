import { z } from "@hono/zod-openapi";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
export const sentTextRecordSchema = z
  .object({
    id: z.string(),
    body: z.string(),
    sentAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
    timeZone: z.string().openapi({ example: "Asia/Tokyo" }),
  })
  .openapi({
    description: "kind が sent_text の変更の record。送った文章は消えない",
  });
