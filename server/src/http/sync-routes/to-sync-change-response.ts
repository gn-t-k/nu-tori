import { match } from "ts-pattern";
import type { SyncChange } from "../../domain/sync/sync-change";

export const toSyncChangeResponse = (change: SyncChange) =>
  match(change)
    .with({ type: "weight_record" }, ({ sequence, weightRecord }) => ({
      sequence,
      kind: "weight_record",
      recordId: weightRecord.id,
      record: {
        id: weightRecord.id,
        weightKg: weightRecord.weightKg,
        measuredAt: weightRecord.measuredAt.getTime(),
        timeZone: weightRecord.timeZone,
        version: weightRecord.version,
        imported: weightRecord.imported,
      },
    }))
    .with({ type: "account_settings" }, ({ sequence, accountSettings }) => ({
      sequence,
      kind: "account_settings",
      recordId: accountSettings.id,
      record: { id: accountSettings.id, sendsUsageData: accountSettings.sendsUsageData },
    }))
    .exhaustive();
