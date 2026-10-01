import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";

const accountSettings = sqliteTable("account_settings", {
  id: text("id").primaryKey(),
  sendsUsageData: integer("sends_usage_data", { mode: "boolean" }).notNull(),
});

const accountSettingChanges = sqliteTable("account_setting_changes", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
  sendsUsageData: integer("sends_usage_data", { mode: "boolean" }).notNull(),
});

// アカウントの設定の表。宣言は durable-object-migrations/ の SQL に合わせる（ずれはテストで気づく）
export const accountSettingsTables = { accountSettings, accountSettingChanges };
