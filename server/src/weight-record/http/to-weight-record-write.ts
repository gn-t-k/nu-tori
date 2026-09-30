import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { SyncWrite } from "../../domain/sync-write";
import type { weightRecordWriteSchemas } from "./weight-record-write-schemas";

export const toWeightRecordWrite = (
  write: z.infer<(typeof weightRecordWriteSchemas)[number]>,
): SyncWrite =>
  match(write)
    .with({ type: "create_weight_record" }, ({ id, weightRecord }): SyncWrite => ({
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
    }))
    .with({ type: "update_weight_record" }, ({ id, weightRecord }): SyncWrite => ({
      id,
      type: "update_weight_record",
      weightRecord: {
        id: weightRecord.id,
        weightKg: weightRecord.weightKg,
        measuredAt: new Date(weightRecord.measuredAt),
        timeZone: weightRecord.timeZone,
        version: weightRecord.version,
      },
    }))
    .with({ type: "source_deleted_weight_record" }, ({ id, weightRecordId }): SyncWrite => ({
      id,
      type: "source_deleted_weight_record",
      weightRecordId,
    }))
    .exhaustive();
