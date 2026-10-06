import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { SyncWrite } from "../../domain/sync-write";
import type { ingredientWriteSchemas } from "./ingredient-write-schemas";

export const toIngredientWrite = (
  write: z.infer<(typeof ingredientWriteSchemas)[number]>,
): SyncWrite =>
  match(write)
    .with({ type: "update_ingredient" }, ({ id, ingredientId, quantity }): SyncWrite => ({
      id,
      type: "update_ingredient",
      ingredientId,
      quantity,
    }))
    .exhaustive();
