import { z } from "@hono/zod-openapi";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
export const mealRecordSchema = z
  .object({
    id: z.string(),
    eatenAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
    eatenAtUtcOffsetSeconds: z.number().int(),
    sentAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
    sentTimeZone: z.string().openapi({ example: "Asia/Tokyo" }),
    entryMethod: z.string().openapi({ example: "captured" }),
    photos: z.array(z.object({ id: z.string() })).openapi({ description: "写真の並び順" }),
  })
  .openapi({
    description:
      "kind が meal の変更の record。消えたら kind が meal_deletion で record が空の変更が届く",
  });
