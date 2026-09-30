import type { z } from "@hono/zod-openapi";
import type { SyncWrite } from "../../domain/sync-write";
import type { createWeightRecordWriteSchema } from "./create-weight-record-write-schema";

export const toCreateWeightRecordWrite = ({
  id,
  weightRecord,
}: z.infer<typeof createWeightRecordWriteSchema>): SyncWrite => ({
  id,
  type: "create_weight_record",
  weightRecord: {
    id: weightRecord.id,
    weightKg: weightRecord.weightKg,
    measuredAt: new Date(weightRecord.measuredAt),
    timeZone: weightRecord.timeZone,
    imported:
      weightRecord.imported === undefined
        ? undefined
        : {
            sourceAppName: weightRecord.imported.sourceAppName,
            sourceBundleId: weightRecord.imported.sourceBundleId,
            healthkitSampleUuid: weightRecord.imported.healthkitSampleUuid,
            bodyFat: weightRecord.imported.bodyFat,
          },
  },
});
