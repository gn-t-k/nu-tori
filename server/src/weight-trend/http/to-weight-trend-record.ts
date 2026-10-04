import type { z } from "@hono/zod-openapi";
import type { WeightTrend } from "../domain/weight-trend";
import type { weightTrendRecordSchema } from "./weight-trend-record-schema";

export const toWeightTrendRecord = (
  value: WeightTrend,
): z.input<typeof weightTrendRecordSchema> => ({
  days: value.map(({ calendarDay, trendKg }) => ({ calendarDay, trendKg })),
});
