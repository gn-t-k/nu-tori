import type { z } from "@hono/zod-openapi";
import type { Meal } from "../domain/meal";
import type { mealRecordSchema } from "./meal-record-schema";

export const toMealRecord = (value: Meal): z.input<typeof mealRecordSchema> => ({
  id: value.id,
  eatenAt: value.eatenAt.getTime(),
  eatenAtUtcOffsetSeconds: value.eatenAtUtcOffsetSeconds,
  sentAt: value.sentAt.getTime(),
  sentTimeZone: value.sentTimeZone,
  entryMethod: value.entryMethod,
  photos: value.photoIds.map((id) => ({ id })),
  ...(value.sentTextId === undefined ? {} : { sentTextId: value.sentTextId }),
});
