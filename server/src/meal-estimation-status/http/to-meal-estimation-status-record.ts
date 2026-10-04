import type { z } from "@hono/zod-openapi";
import type { MealEstimationStatus } from "../domain/meal-estimation-status";
import type { mealEstimationStatusRecordSchema } from "./meal-estimation-status-record-schema";

export const toMealEstimationStatusRecord = (
  value: MealEstimationStatus,
  mealId: string,
): z.input<typeof mealEstimationStatusRecordSchema> => ({ mealId, status: value });
