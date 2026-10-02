import { desc, eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import type { UsualWeighingTimeStore } from "../domain/usual-weighing-time-store";
import { usualWeighingTimeTables } from "./usual-weighing-time-tables";

const { syncRequestLogs, syncWriteReceipts } = syncLedgerTables;
const { usualWeighingTimes, usualWeighingTimeChanges } = usualWeighingTimeTables;

export const createUsualWeighingTimeStore = (
  db: DrizzleSqliteDODatabase,
): UsualWeighingTimeStore => ({
  find: () => {
    const record = db.select({ id: usualWeighingTimes.id }).from(usualWeighingTimes).get();
    if (record === undefined) {
      return undefined;
    }
    // 今の値は、控えの要求の受け取った時刻の降順、同じ要求の中は要求の中の位置の降順で最初の学び直し
    const latestChange = db
      .select({ minuteOfDay: usualWeighingTimeChanges.minuteOfDay })
      .from(usualWeighingTimeChanges)
      .innerJoin(
        syncWriteReceipts,
        eq(syncWriteReceipts.id, usualWeighingTimeChanges.syncWriteReceiptId),
      )
      .innerJoin(syncRequestLogs, eq(syncRequestLogs.id, syncWriteReceipts.syncRequestLogId))
      .orderBy(desc(syncRequestLogs.receivedAt), desc(syncWriteReceipts.positionInRequest))
      .limit(1)
      .get();
    if (latestChange === undefined) {
      throw new Error("いつもの時刻の記録に、学び直しが1つも無い");
    }
    return { id: record.id, minuteOfDay: latestChange.minuteOfDay };
  },
  insert: (id) => {
    db.insert(usualWeighingTimes).values({ id }).run();
  },
  insertChange: (receiptId, minuteOfDay) => {
    db.insert(usualWeighingTimeChanges)
      .values({ syncWriteReceiptId: receiptId.value, minuteOfDay })
      .run();
  },
});
