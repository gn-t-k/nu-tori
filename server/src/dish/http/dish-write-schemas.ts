import { z } from "@hono/zod-openapi";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";

const deleteDishWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("delete_dish"),
    dishId: z.string().min(1),
  })
  .openapi("DeleteDishWrite");

// 料理の書き込みのスキーマ。型を保つため as const で並べる
export const dishWriteSchemas = [deleteDishWriteSchema] as const;
