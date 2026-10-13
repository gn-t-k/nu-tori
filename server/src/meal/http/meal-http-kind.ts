import { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import { recordIdSchema } from "../../domain/record-id";
import type { SyncWrite } from "../../domain/sync-write";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";
import type { Meal } from "../domain/meal";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
const mealRecordSchema = z
  .object({
    id: z.string(),
    eatenAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
    eatenAtUtcOffsetSeconds: z.number().int(),
    sentAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
    sentTimeZone: z.string().openapi({ example: "Asia/Tokyo" }),
    entryMethod: z.string().openapi({ example: "captured" }),
    photos: z.array(z.object({ id: z.string() })).openapi({ description: "写真の並び順" }),
    sentTextId: z.string().optional().openapi({
      description: "文章の食事なら、作った送った文章の ID。写真の食事には無い",
    }),
  })
  .openapi({
    description:
      "kind が meal の変更の record。消えたら kind が meal_deletion で record が空の変更が届く",
  });

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
      id: recordIdSchema,
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
        .array(z.object({ id: recordIdSchema }))
        .openapi({ description: "並びが写真の並び順" }),
    }),
  })
  .openapi("CreateMealWrite");

const deleteMealWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("delete_meal"),
    mealId: recordIdSchema,
  })
  .openapi("DeleteMealWrite");

// 直すのは撮った時刻だけ。サーバーでは時刻を確かめない（#332 の「受け付ける値」）
const updateMealWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("update_meal"),
    mealId: recordIdSchema,
    eatenAt: timestampSchema,
  })
  .openapi("UpdateMealWrite");

// 食事の書き込みのスキーマ。型を保つため as const で並べる
const mealWriteSchemas = [
  createMealWriteSchema,
  deleteMealWriteSchema,
  updateMealWriteSchema,
] as const;

export const mealHttpKind: HttpRecordKind<
  Meal,
  (typeof mealWriteSchemas)[number],
  typeof mealRecordSchema
> = {
  writes: {
    schemas: mealWriteSchemas,
    toWrite: (write) =>
      match(write)
        .with({ type: "create_meal" }, ({ id, meal }): SyncWrite => ({
          id,
          type: "create_meal",
          meal: {
            id: meal.id,
            eatenAt: new Date(meal.eatenAt),
            eatenAtUtcOffsetSeconds: meal.eatenAtUtcOffsetSeconds,
            sentAt: new Date(meal.sentAt),
            sentTimeZone: meal.sentTimeZone,
            entryMethod: meal.entryMethod,
            photoIds: meal.photos.map((photo) => photo.id),
          },
        }))
        .with({ type: "delete_meal" }, ({ id, mealId }): SyncWrite => ({
          id,
          type: "delete_meal",
          mealId,
        }))
        .with({ type: "update_meal" }, ({ id, mealId, eatenAt }): SyncWrite => ({
          id,
          type: "update_meal",
          mealId,
          eatenAt: new Date(eatenAt),
        }))
        .exhaustive(),
  },
  recordSchema: mealRecordSchema,
  toRecord: (value) => ({
    id: value.id,
    eatenAt: value.eatenAt.getTime(),
    eatenAtUtcOffsetSeconds: value.eatenAtUtcOffsetSeconds,
    sentAt: value.sentAt.getTime(),
    sentTimeZone: value.sentTimeZone,
    entryMethod: value.entryMethod,
    photos: value.photoIds.map((id) => ({ id })),
    ...(value.sentTextId === undefined ? {} : { sentTextId: value.sentTextId }),
  }),
};
