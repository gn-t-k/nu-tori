import type { z } from "@hono/zod-openapi";
import type { DishEstimationStatus } from "../domain/dish-estimation-status";
import type { dishEstimationStatusRecordSchema } from "./dish-estimation-status-record-schema";

export const toDishEstimationStatusRecord = (
  value: DishEstimationStatus,
  dishId: string,
): z.input<typeof dishEstimationStatusRecordSchema> => ({ dishId, status: value });
