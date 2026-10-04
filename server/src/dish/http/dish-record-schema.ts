import { z } from "@hono/zod-openapi";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
export const dishRecordSchema = z
  .object({
    id: z.string(),
    mealId: z.string(),
    name: z.string(),
    quantity: z.number(),
    unit: z.string(),
    positionInMeal: z.number().int(),
    version: z.number().int(),
  })
  .openapi({
    description:
      "kind が dish の変更の record。消えたら kind が dish_deletion で record が空の変更が届く",
  });
