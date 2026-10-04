import type { z } from "@hono/zod-openapi";
import type { WeightRecord } from "../domain/weight-record";
import type { weightRecordRecordSchema } from "./weight-record-record-schema";

export const toWeightRecordRecord = (
  value: WeightRecord,
): z.input<typeof weightRecordRecordSchema> => ({
  id: value.id,
  weightKg: value.weightKg,
  measuredAt: value.measuredAt.getTime(),
  timeZone: value.timeZone,
  version: value.version,
  imported: value.imported,
});
