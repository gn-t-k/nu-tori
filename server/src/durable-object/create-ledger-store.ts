import { desc, eq, gt, sql } from "drizzle-orm";
import { drizzle, type DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { RecordType } from "../domain/record-type";
import type { LedgerStore } from "../domain/sync-ledger/ledger-store";
import type { SyncWriteOutcome } from "../domain/sync-write-outcome";
import { syncLedgerTables } from "./sync-ledger-tables";

const {
  syncRequestLogs,
  syncPushLogs,
  syncPullLogs,
  syncWriteReceipts,
  syncWriteRejections,
  recordChanges,
  syncWriteRecordChanges,
} = syncLedgerTables;

// 帳簿の置き場。種類の中身は知らず、要求の控え・書き込みの控え・変更の並びだけを持つ
export const createLedgerStore = (storage: DurableObjectStorage): LedgerStore<RecordType> => {
  const db = drizzle(storage);
  return {
    transaction: (run) => storage.transactionSync(run),
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
    findWriteReceipt: (writeId) => {
      const row = db
        .select({
          result: syncWriteReceipts.result,
          reason: syncWriteRejections.reason,
          recordType: syncWriteReceipts.recordType,
          recordId: syncWriteReceipts.recordId,
        })
        .from(syncWriteReceipts)
        .leftJoin(
          syncWriteRejections,
          eq(syncWriteRejections.syncWriteReceiptId, syncWriteReceipts.id),
        )
        .where(eq(syncWriteReceipts.id, writeId))
        .get();
      return row === undefined
        ? undefined
        : { outcome: toOutcome(row), recordType: row.recordType, recordId: row.recordId };
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
    clientState: Parameters<LedgerStore<RecordType>["insertPushRequestLog"]>[0]["clientState"];
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
