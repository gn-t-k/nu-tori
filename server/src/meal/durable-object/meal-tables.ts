import { index, integer, sqliteTable, text } from "drizzle-orm/sqlite-core";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";

const meals = sqliteTable(
  "meals",
  {
    id: text("id").primaryKey(),
    eatenAt: integer("eaten_at", { mode: "timestamp_ms" }).notNull(),
    // IANA 名でなく時差で持つ理由は #188 の Schema changes。範囲はドメイン層で確かめる
    eatenAtUtcOffsetSeconds: integer("eaten_at_utc_offset_seconds").notNull(),
    sentAt: integer("sent_at", { mode: "timestamp_ms" }).notNull(),
    sentTimeZone: text("sent_time_zone").notNull(),
    // 値の名前は、食事の種類のチケットで決めて enum を足す
    entryMethod: text("entry_method").notNull(),
  },
  (table) => [index("meals_eaten_at").on(table.eatenAt)],
);

const mealDeletions = sqliteTable("meal_deletions", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
});

// 食事の表。写真の表は meal-photo-tables.ts。宣言は durable-object-migrations/ の SQL に合わせる
export const mealTables = {
  meals,
  mealDeletions,
};
