import { integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import { noticeTypes } from "../domain/notice";

const notices = sqliteTable("notices", {
  id: text("id").primaryKey(),
  noticeType: text("notice_type", { enum: noticeTypes }).notNull(),
  issuedAt: integer("issued_at", { mode: "timestamp_ms" }).notNull(),
  timeZone: text("time_zone").notNull(),
});

const missedRecordNotices = sqliteTable("missed_record_notices", {
  noticeId: text("notice_id")
    .primaryKey()
    .references(() => notices.id, { onDelete: "cascade" }),
  targetOn: text("target_on").notNull(),
});

const noticeResponses = sqliteTable(
  "notice_responses",
  {
    syncWriteReceiptId: text("sync_write_receipt_id")
      .primaryKey()
      .references(() => syncLedgerTables.syncWriteReceipts.id),
    noticeId: text("notice_id")
      .notNull()
      .references(() => notices.id, { onDelete: "cascade" }),
    respondedAt: integer("responded_at", { mode: "timestamp_ms" }).notNull(),
    timeZone: text("time_zone").notNull(),
  },
  (table) => [uniqueIndex("notice_responses_notice_id").on(table.noticeId)],
);

// 知らせの表（親、記録忘れの知らせの子、答え）。宣言は durable-object-migrations/ の SQL に合わせる
export const noticeTables = {
  notices,
  missedRecordNotices,
  noticeResponses,
};
