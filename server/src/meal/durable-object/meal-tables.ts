import { index, integer, sqliteTable, text } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";

const meals = sqliteTable(
  "meals",
  {
    id: text("id").$type<RecordId>().primaryKey(),
    eatenAt: integer("eaten_at", { mode: "timestamp_ms" }).notNull(),
    // IANA 名でなく時差で持つ理由は #188 の Schema changes。範囲はドメイン層で確かめる
    eatenAtUtcOffsetSeconds: integer("eaten_at_utc_offset_seconds").notNull(),
    sentAt: integer("sent_at", { mode: "timestamp_ms" }).notNull(),
    sentTimeZone: text("sent_time_zone").notNull(),
    entryMethod: text("entry_method", { enum: ["captured", "picked"] }).notNull(),
  },
  (table) => [index("meals_eaten_at").on(table.eatenAt)],
);

const mealDeletions = sqliteTable("meal_deletions", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
});

// 時刻の修正。食事は控えの record_id で、食事を消す口が控えから探して消す。meals.eaten_at は作ったときの時刻のまま書き換えない
const mealEatenAtCorrections = sqliteTable(
  "meal_eaten_at_corrections",
  {
    syncWriteReceiptId: text("sync_write_receipt_id")
      .primaryKey()
      .references(() => syncLedgerTables.syncWriteReceipts.id),
    eatenAt: integer("eaten_at", { mode: "timestamp_ms" }).notNull(),
  },
  (table) => [index("meal_eaten_at_corrections_eaten_at").on(table.eatenAt)],
);

// 食事の表。写真の表は meal-photo-tables.ts。宣言は durable-object-migrations/ の SQL に合わせる
export const mealTables = {
  meals,
  mealEatenAtCorrections,
  mealDeletions,
};
