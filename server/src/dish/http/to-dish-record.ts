import type { z } from "@hono/zod-openapi";
import type { Dish } from "../domain/dish";
import type { dishRecordSchema } from "./dish-record-schema";

export const toDishRecord = (value: Dish): z.input<typeof dishRecordSchema> => ({
  id: value.id,
  mealId: value.mealId,
  name: value.name,
  quantity: value.quantity,
  unit: value.unit,
  positionInMeal: value.positionInMeal,
  version: value.version,
});
