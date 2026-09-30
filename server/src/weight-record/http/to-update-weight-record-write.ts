import type { z } from "@hono/zod-openapi";
import type { SyncWrite } from "../../domain/sync-write";
import type { updateWeightRecordWriteSchema } from "./update-weight-record-write-schema";

export const toUpdateWeightRecordWrite = ({
  id,
  weightRecord,
}: z.infer<typeof updateWeightRecordWriteSchema>): SyncWrite => ({
  id,
  type: "update_weight_record",
  weightRecord: {
    id: weightRecord.id,
    weightKg: weightRecord.weightKg,
    measuredAt: new Date(weightRecord.measuredAt),
    timeZone: weightRecord.timeZone,
    version: weightRecord.version,
  },
});
