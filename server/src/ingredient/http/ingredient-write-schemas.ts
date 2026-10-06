import { z } from "@hono/zod-openapi";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";

const updateIngredientWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("update_ingredient"),
    ingredientId: z.string().min(1),
    quantity: z.number().openapi({ description: "直した量。単位は材料の単位のまま" }),
  })
  .openapi("UpdateIngredientWrite");

// 材料の書き込みのスキーマ。型を保つため as const で並べる
export const ingredientWriteSchemas = [updateIngredientWriteSchema] as const;
