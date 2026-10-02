import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";

// 行は1つだけ。DB では止めず、decide が行を読んでから ID を振ることで守る
const usualWeighingTimes = sqliteTable("usual_weighing_times", {
  id: text("id").primaryKey(),
});

// 学び直しで値が変わった事実。今の値は、控えの要求の received_at の降順、
// 同じ要求の中は position_in_request の降順で最初の行
const usualWeighingTimeChanges = sqliteTable("usual_weighing_time_changes", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
  minuteOfDay: integer("minute_of_day").notNull(),
});

// いつもの時刻の表。宣言は durable-object-migrations/ の SQL に合わせる
export const usualWeighingTimeTables = {
  usualWeighingTimes,
  usualWeighingTimeChanges,
};
