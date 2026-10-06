import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { SyncWrite } from "../../domain/sync-write";
import type { mealWriteSchemas } from "./meal-write-schemas";

export const toMealWrite = (write: z.infer<(typeof mealWriteSchemas)[number]>): SyncWrite =>
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
    .exhaustive();
