import { z } from "@hono/zod-openapi";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";

// Date が表せる範囲。これを超える時刻は、日付の計算で例外になる
const maximumTimestamp = 8.64e15;
const timestampSchema = z
  .number()
  .int()
  .min(-maximumTimestamp)
  .max(maximumTimestamp)
  .openapi({ description: "UNIX 時刻のミリ秒（UTC）" });

const createMealWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("create_meal"),
    meal: z.object({
      id: z.string().min(1),
      eatenAt: timestampSchema,
      eatenAtUtcOffsetSeconds: z
        .number()
        .int()
        .openapi({ description: "撮った時刻の UTC との時差の秒", example: 32_400 }),
      sentAt: timestampSchema,
      sentTimeZone: z.string().openapi({ example: "Asia/Tokyo" }),
      entryMethod: z.string().openapi({
        description: "入口。撮った（captured）か、撮っておいた写真を選んだ（picked）か",
        example: "captured",
      }),
      photos: z
        .array(z.object({ id: z.string().min(1) }))
        .openapi({ description: "並びが写真の並び順" }),
    }),
  })
  .openapi("CreateMealWrite");

const deleteMealWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("delete_meal"),
    mealId: z.string().min(1),
  })
  .openapi("DeleteMealWrite");

// 直すのは撮った時刻だけ。サーバーでは時刻を確かめない（#332 の「受け付ける値」）
const updateMealWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("update_meal"),
    mealId: z.string().min(1),
    eatenAt: timestampSchema,
  })
  .openapi("UpdateMealWrite");

// 食事の書き込みのスキーマ。型を保つため as const で並べる
export const mealWriteSchemas = [
  createMealWriteSchema,
  deleteMealWriteSchema,
  updateMealWriteSchema,
] as const;
