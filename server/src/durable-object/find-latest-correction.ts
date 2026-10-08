import { and, desc, eq, getTableColumns } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { CorrectionTable } from "./correction-table";
import { syncLedgerTables } from "./sync-ledger-tables";

const { syncWriteReceipts, syncWriteRecordChanges } = syncLedgerTables;

// 記録を書き換えた控えの修正のうち、受け取った順（控えを当てたときの変更の通し番号）でいちばんあとのものの値と通し番号。修正が無ければ undefined。
// 値の列は修正の表の列の名前で受け、別の表の列を渡せないようにする。戻り値の型は、表と列の名前の型引数から Drizzle が決めるので書かない
export const findLatestCorrection = <
  TCorrections extends CorrectionTable,
  TValueColumn extends keyof TCorrections["_"]["columns"],
>(
  db: DrizzleSqliteDODatabase,
  corrections: TCorrections,
  valueColumn: TValueColumn,
  { recordType, recordId }: Pick<typeof syncWriteReceipts.$inferSelect, "recordType" | "recordId">,
) =>
  db
    .select({
      value: getTableColumns(corrections)[valueColumn],
      sequence: syncWriteRecordChanges.recordChangeSequence,
    })
    .from(corrections)
    .innerJoin(syncWriteReceipts, eq(syncWriteReceipts.id, corrections.syncWriteReceiptId))
    .innerJoin(
      syncWriteRecordChanges,
      eq(syncWriteRecordChanges.syncWriteReceiptId, corrections.syncWriteReceiptId),
    )
    .where(
      and(eq(syncWriteReceipts.recordType, recordType), eq(syncWriteReceipts.recordId, recordId)),
    )
    .orderBy(desc(syncWriteRecordChanges.recordChangeSequence))
    .limit(1)
    .get();
