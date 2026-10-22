import { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import { recordIdSchema } from "../../domain/record-id";
import type { SyncWrite } from "../../domain/sync-write";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";
import type { Dish } from "../domain/dish";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
const dishRecordSchema = z
  .object({
    id: z.string(),
    mealId: z.string(),
    name: z.string().openapi({ description: "今の名前" }),
    // 量の無い料理（推定し直しが一度も当たっていない料理）は、量と単位と量の出どころを省く。
    // 1つ前の版のアプリは読めないので、最低バージョンで締め出す（#332 の「移行の決まりの例外」）。
    // 3つは揃って有るか無いかだが、#188 から出ている quantity・unit のキーを変えないため、組にせず平らに持つ
    quantity: z.number().optional().openapi({ description: "今の量。量の無い料理は省く" }),
    unit: z.string().optional().openapi({ description: "量の単位。量の無い料理は省く" }),
    quantitySource: z.enum(["estimated", "corrected"]).optional().openapi({
      description:
        "量の出どころ。推定したまま（estimated）か、料理の量を直した（corrected）か。量の無い料理は省く",
    }),
    positionInMeal: z.number().int(),
    version: z.number().int(),
  })
  .openapi({
    description:
      "kind が dish の変更の record。消えたら kind が dish_deletion で record が空の変更が届く",
  });

const createDishWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("create_dish"),
    dishId: recordIdSchema.meta({ description: "端末が振る UUID v4" }),
    mealId: recordIdSchema,
    name: z.string(),
    positionInMeal: z.number().int().openapi({
      description:
        "端末のキャッシュの、その食事の料理の最後の次の値。一意にせず、同じなら ID の順で並べる",
    }),
  })
  .openapi("CreateDishWrite");

const deleteDishWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("delete_dish"),
    dishId: recordIdSchema,
  })
  .openapi("DeleteDishWrite");

const updateDishWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("update_dish"),
    dishId: recordIdSchema,
    name: z.string().openapi({ description: "今の名前か、直した名前" }),
    quantity: z
      .object({
        value: z.number().openapi({ description: "今の量か、直した量。単位は料理の単位のまま" }),
        proportionedIngredients: z
          .array(z.object({ ingredientId: recordIdSchema, quantity: z.number() }))
          .openapi({
            description:
              "量を直したときに、端末が今の材料の量を同じ割合で変えた量。材料ごとに1つ。サーバーは割合を計算し直さない",
          }),
      })
      .optional()
      .openapi({ description: "名前だけを直すときは省く。量を直すときは名前と量を運ぶ" }),
  })
  .openapi("UpdateDishWrite");

// 料理の書き込みのスキーマ。型を保つため as const で並べる
const dishWriteSchemas = [
  deleteDishWriteSchema,
  updateDishWriteSchema,
  createDishWriteSchema,
] as const;

export const dishHttpKind: HttpRecordKind<
  Dish,
  (typeof dishWriteSchemas)[number],
  typeof dishRecordSchema
> = {
  writes: {
    schemas: dishWriteSchemas,
    toWrite: (write) =>
      match(write)
        .with(
          { type: "create_dish" },
          ({ id, dishId, mealId, name, positionInMeal }): SyncWrite => ({
            id,
            type: "create_dish",
            dishId,
            mealId,
            name,
            positionInMeal,
          }),
        )
        .with({ type: "delete_dish" }, ({ id, dishId }): SyncWrite => ({
          id,
          type: "delete_dish",
          dishId,
        }))
        .with({ type: "update_dish" }, ({ id, dishId, name, quantity }): SyncWrite => ({
          id,
          type: "update_dish",
          dishId,
          name,
          quantity,
        }))
        .exhaustive(),
  },
  recordSchema: dishRecordSchema,
  toRecord: (value) => ({
    id: value.id,
    mealId: value.mealId,
    name: value.name,
    ...(value.quantity === undefined
      ? {}
      : {
          quantity: value.quantity.value,
          unit: value.quantity.unit,
          quantitySource: value.quantity.source,
        }),
    positionInMeal: value.positionInMeal,
    version: value.version,
  }),
};
