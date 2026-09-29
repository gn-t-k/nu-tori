import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { SyncWrite } from "../../domain/sync/sync-write";
import type { syncWriteSchema } from "./sync-write-schema";

export const toSyncWrite = (write: z.infer<typeof syncWriteSchema>): SyncWrite =>
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
    .with({ type: "update_account_settings" }, ({ id, accountSettings }): SyncWrite => ({
      id,
      type: "update_account_settings",
      accountSettings: { id: accountSettings.id, sendsUsageData: accountSettings.sendsUsageData },
    }))
    .exhaustive();
