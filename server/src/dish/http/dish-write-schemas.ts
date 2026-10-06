import { z } from "@hono/zod-openapi";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";

const createDishWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("create_dish"),
    dishId: z.string().min(1).openapi({ description: "端末が振る UUID v4" }),
    mealId: z.string().min(1),
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
    dishId: z.string().min(1),
  })
  .openapi("DeleteDishWrite");

const updateDishWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("update_dish"),
    dishId: z.string().min(1),
    name: z.string().openapi({ description: "今の名前か、直した名前" }),
    quantity: z
      .object({
        value: z.number().openapi({ description: "今の量か、直した量。単位は料理の単位のまま" }),
        proportionedIngredients: z
          .array(z.object({ ingredientId: z.string().min(1), quantity: z.number() }))
          .openapi({
            description:
              "量を直したときに、端末が今の材料の量を同じ割合で変えた量。材料ごとに1つ。サーバーは割合を計算し直さない",
          }),
      })
      .optional()
      .openapi({ description: "量の無い料理（推定し直しが一度も当たっていない料理）は省く" }),
  })
  .openapi("UpdateDishWrite");

// 料理の書き込みのスキーマ。型を保つため as const で並べる
export const dishWriteSchemas = [
  deleteDishWriteSchema,
  updateDishWriteSchema,
  createDishWriteSchema,
] as const;
