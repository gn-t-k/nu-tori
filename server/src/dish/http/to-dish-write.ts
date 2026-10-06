import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { SyncWrite } from "../../domain/sync-write";
import type { dishWriteSchemas } from "./dish-write-schemas";

export const toDishWrite = (write: z.infer<(typeof dishWriteSchemas)[number]>): SyncWrite =>
  match(write)
    .with({ type: "create_dish" }, ({ id, dishId, mealId, name, positionInMeal }): SyncWrite => ({
      id,
      type: "create_dish",
      dishId,
      mealId,
      name,
      positionInMeal,
    }))
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
    .exhaustive();
