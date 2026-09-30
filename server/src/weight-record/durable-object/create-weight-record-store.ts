import { and, eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import type { WeightRecord } from "../domain/weight-record";
import type { WeightRecordStore } from "../domain/weight-record-store";
import { weightRecordTables } from "./weight-record-tables";

const { syncWriteReceipts } = syncLedgerTables;
const { weightRecords, importedWeightRecords, importedBodyFatPercentages, weightRecordDeletions } =
  weightRecordTables;

export const createWeightRecordStore = (db: DrizzleSqliteDODatabase): WeightRecordStore => ({
  find: (id) => {
    const row = db
      .select({
        record: weightRecords,
        imported: importedWeightRecords,
        bodyFat: importedBodyFatPercentages,
      })
      .from(weightRecords)
      .leftJoin(importedWeightRecords, eq(importedWeightRecords.weightRecordId, weightRecords.id))
      .leftJoin(
        importedBodyFatPercentages,
        eq(importedBodyFatPercentages.weightRecordId, weightRecords.id),
      )
      .where(eq(weightRecords.id, id))
      .get();
    return row === undefined ? undefined : toWeightRecord(row);
  },
  existsImportedSample: (healthkitSampleUuid) =>
    db
      .select({ weightRecordId: importedWeightRecords.weightRecordId })
      .from(importedWeightRecords)
      .where(eq(importedWeightRecords.healthkitSampleUuid, healthkitSampleUuid))
      .all().length > 0,
  hasDeletion: (recordId) =>
    db
      .select({ id: weightRecordDeletions.syncWriteReceiptId })
      .from(weightRecordDeletions)
      .innerJoin(
        syncWriteReceipts,
        eq(syncWriteReceipts.id, weightRecordDeletions.syncWriteReceiptId),
      )
      .where(
        and(
          eq(syncWriteReceipts.recordType, "weight_record"),
          eq(syncWriteReceipts.recordId, recordId),
        ),
      )
      .all().length > 0,
  insert: ({ id, weightKg, measuredAt, timeZone, version, imported }) => {
    db.insert(weightRecords).values({ id, weightKg, measuredAt, timeZone, version }).run();
    if (imported === undefined) {
      return;
    }
    db.insert(importedWeightRecords)
      .values({
        weightRecordId: id,
        sourceAppName: imported.sourceAppName,
        sourceBundleId: imported.sourceBundleId,
        healthkitSampleUuid: imported.healthkitSampleUuid,
      })
      .run();
    if (imported.bodyFat === undefined) {
      return;
    }
    db.insert(importedBodyFatPercentages)
      .values({
        weightRecordId: id,
        bodyFatPercentage: imported.bodyFat.percentage,
        healthkitSampleUuid: imported.bodyFat.healthkitSampleUuid,
      })
      .run();
  },
  update: (id, { weightKg, measuredAt, timeZone, version }) => {
    db.update(weightRecords)
      .set({ weightKg, measuredAt, timeZone, version })
      .where(eq(weightRecords.id, id))
      .run();
  },
  remove: (id) => {
    db.delete(weightRecords).where(eq(weightRecords.id, id)).run();
  },
  insertDeletion: (receiptId) => {
    db.insert(weightRecordDeletions).values({ syncWriteReceiptId: receiptId.value }).run();
  },
});

const toWeightRecord = ({
  record,
  imported,
  bodyFat,
}: {
  record: typeof weightRecords.$inferSelect;
  imported: typeof importedWeightRecords.$inferSelect | null;
  bodyFat: typeof importedBodyFatPercentages.$inferSelect | null;
}): WeightRecord => ({
  id: record.id,
  weightKg: record.weightKg,
  measuredAt: record.measuredAt,
  timeZone: record.timeZone,
  version: record.version,
  imported:
    imported === null
      ? undefined
      : {
          sourceAppName: imported.sourceAppName,
          sourceBundleId: imported.sourceBundleId,
          healthkitSampleUuid: imported.healthkitSampleUuid,
          bodyFat:
            bodyFat === null
              ? undefined
              : {
                  percentage: bodyFat.bodyFatPercentage,
                  healthkitSampleUuid: bodyFat.healthkitSampleUuid,
                },
        },
});
