import { and, desc, eq, gt, sql } from "drizzle-orm";
import { drizzle, type DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { accountSettingsTables } from "../account-settings/durable-object/account-settings-tables";
import type { SyncStore } from "../domain/sync-store";
import type { SyncWriteOutcome } from "../domain/sync-write-outcome";
import type { WeightRecord } from "../weight-record/domain/weight-record";
import { weightRecordTables } from "../weight-record/durable-object/weight-record-tables";
import { firstSignInTables } from "./first-sign-in-tables";
import { syncLedgerTables } from "./sync-ledger-tables";

const { firstSignIns } = firstSignInTables;
const {
  syncRequestLogs,
  syncPushLogs,
  syncPullLogs,
  syncWriteReceipts,
  syncWriteRejections,
  recordChanges,
  syncWriteRecordChanges,
} = syncLedgerTables;
const { weightRecords, importedWeightRecords, importedBodyFatPercentages, weightRecordDeletions } =
  weightRecordTables;
const { accountSettings, accountSettingChanges } = accountSettingsTables;

export const createSyncStore = (storage: DurableObjectStorage): SyncStore => {
  const db = drizzle(storage);
  return {
    transaction: (run) => storage.transactionSync(run),
    findStartedOn: () =>
      db.select({ startedOn: firstSignIns.startedOn }).from(firstSignIns).get()?.startedOn,
    findLatestRequestReceivedAt: () =>
      db
        .select({ receivedAt: syncRequestLogs.receivedAt })
        .from(syncRequestLogs)
        .orderBy(desc(syncRequestLogs.receivedAt))
        .limit(1)
        .get()?.receivedAt,
    insertPushRequestLog: ({ id, receivedAt, clientState, isFinalBatch }) => {
      insertRequestLog(db, { id, receivedAt, clientState });
      db.insert(syncPushLogs).values({ syncRequestLogId: id, isFinalBatch }).run();
    },
    insertPullRequestLog: ({ id, receivedAt, clientState, afterSequence }) => {
      insertRequestLog(db, { id, receivedAt, clientState });
      db.insert(syncPullLogs)
        .values({ syncRequestLogId: id, afterChangeSequence: afterSequence })
        .run();
    },
    findWriteOutcome: (writeId) => {
      const row = db
        .select({ result: syncWriteReceipts.result, reason: syncWriteRejections.reason })
        .from(syncWriteReceipts)
        .leftJoin(
          syncWriteRejections,
          eq(syncWriteRejections.syncWriteReceiptId, syncWriteReceipts.id),
        )
        .where(eq(syncWriteReceipts.id, writeId))
        .get();
      return row === undefined ? undefined : toOutcome(row);
    },
    insertWriteReceipt: ({
      writeId,
      requestLogId,
      positionInRequest,
      kind,
      recordType,
      recordId,
      outcome,
    }) => {
      db.insert(syncWriteReceipts)
        .values({
          id: writeId,
          syncRequestLogId: requestLogId,
          positionInRequest,
          kind,
          recordType,
          recordId,
          result: outcome.result,
        })
        .run();
      if (outcome.result === "rejected") {
        db.insert(syncWriteRejections)
          .values({ syncWriteReceiptId: writeId, reason: outcome.reason })
          .run();
      }
    },
    findWeightRecord: (id) => {
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
    existsWeightRecordDeletion: (recordId) =>
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
    insertWeightRecord: ({ id, weightKg, measuredAt, timeZone, version, imported }) => {
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
    updateWeightRecord: (id, { weightKg, measuredAt, timeZone, version }) => {
      db.update(weightRecords)
        .set({ weightKg, measuredAt, timeZone, version })
        .where(eq(weightRecords.id, id))
        .run();
    },
    deleteWeightRecord: (id) => {
      db.delete(weightRecords).where(eq(weightRecords.id, id)).run();
    },
    insertWeightRecordDeletion: (writeId) => {
      db.insert(weightRecordDeletions).values({ syncWriteReceiptId: writeId }).run();
    },
    findAccountSettings: () =>
      db
        .select({ id: accountSettings.id, sendsUsageData: accountSettings.sendsUsageData })
        .from(accountSettings)
        .get(),
    insertAccountSettings: ({ id, sendsUsageData }) => {
      db.insert(accountSettings).values({ id, sendsUsageData }).run();
    },
    updateAccountSettings: (sendsUsageData) => {
      db.update(accountSettings).set({ sendsUsageData }).run();
    },
    insertAccountSettingChange: ({ writeId, sendsUsageData }) => {
      db.insert(accountSettingChanges)
        .values({ syncWriteReceiptId: writeId, sendsUsageData })
        .run();
    },
    insertRecordChange: ({ recordType, recordId, writeId }) => {
      const change = db
        .insert(recordChanges)
        .values({ recordType, recordId })
        .returning({ sequence: recordChanges.sequence })
        .get();
      db.insert(syncWriteRecordChanges)
        .values({ recordChangeSequence: change.sequence, syncWriteReceiptId: writeId })
        .run();
    },
    findLatestChangePerRecord: (afterSequence, limit) => {
      const latestSequence = sql<number>`max(${recordChanges.sequence})`;
      return db
        .select({
          sequence: latestSequence,
          recordType: recordChanges.recordType,
          recordId: recordChanges.recordId,
        })
        .from(recordChanges)
        .where(gt(recordChanges.sequence, afterSequence))
        .groupBy(recordChanges.recordType, recordChanges.recordId)
        .orderBy(latestSequence)
        .limit(limit)
        .all();
    },
  };
};

const insertRequestLog = (
  db: DrizzleSqliteDODatabase,
  {
    id,
    receivedAt,
    clientState,
  }: {
    id: string;
    receivedAt: Date;
    clientState: Parameters<SyncStore["insertPushRequestLog"]>[0]["clientState"];
  },
): void => {
  db.insert(syncRequestLogs)
    .values({
      id,
      deviceId: clientState.deviceId,
      receivedAt,
      timeZone: clientState.timeZone,
      appVersion: clientState.appVersion,
      osVersion: clientState.osVersion,
      pendingWriteCount: clientState.pendingWriteCount,
      oldestPendingWriteAgeSeconds: clientState.oldestPendingWriteAgeSeconds ?? null,
      pendingPhotoCount: clientState.pendingPhotoCount,
    })
    .run();
};

const toOutcome = (row: {
  result: typeof syncWriteReceipts.$inferSelect.result;
  reason: typeof syncWriteRejections.$inferSelect.reason | null;
}): SyncWriteOutcome => {
  if (row.result !== "rejected") {
    return { result: row.result };
  }
  if (row.reason === null) {
    throw new Error("拒んだ書き込みに理由が無い");
  }
  return { result: "rejected", reason: row.reason };
};

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
