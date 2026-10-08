import { and, eq, inArray } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { CorrectionTable } from "./correction-table";
import { syncLedgerTables } from "./sync-ledger-tables";

const { syncWriteReceipts } = syncLedgerTables;

// 記録を書き換えた控えを指す修正の行を消す。控えは残す
export const removeCorrectionsOfRecord = (
  db: DrizzleSqliteDODatabase,
  corrections: CorrectionTable,
  { recordType, recordId }: Pick<typeof syncWriteReceipts.$inferSelect, "recordType" | "recordId">,
): void => {
  db.delete(corrections)
    .where(
      inArray(
        corrections.syncWriteReceiptId,
        db
          .select({ id: syncWriteReceipts.id })
          .from(syncWriteReceipts)
          .where(
            and(
              eq(syncWriteReceipts.recordType, recordType),
              eq(syncWriteReceipts.recordId, recordId),
            ),
          ),
      ),
    )
    .run();
};
