import { integer, real, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";

const weightRecords = sqliteTable("weight_records", {
  id: text("id").primaryKey(),
  weightKg: real("weight_kg").notNull(),
  measuredAt: integer("measured_at", { mode: "timestamp_ms" }).notNull(),
  timeZone: text("time_zone").notNull(),
  version: integer("version").notNull(),
});

const importedWeightRecords = sqliteTable(
  "imported_weight_records",
  {
    weightRecordId: text("weight_record_id")
      .primaryKey()
      .references(() => weightRecords.id, { onDelete: "cascade" }),
    sourceAppName: text("source_app_name").notNull(),
    sourceBundleId: text("source_bundle_id").notNull(),
    healthkitSampleUuid: text("healthkit_sample_uuid").notNull(),
  },
  (table) => [
    uniqueIndex("imported_weight_records_healthkit_sample_uuid").on(table.healthkitSampleUuid),
  ],
);

const importedBodyFatPercentages = sqliteTable("imported_body_fat_percentages", {
  weightRecordId: text("weight_record_id")
    .primaryKey()
    .references(() => importedWeightRecords.weightRecordId, { onDelete: "cascade" }),
  bodyFatPercentage: real("body_fat_percentage").notNull(),
  healthkitSampleUuid: text("healthkit_sample_uuid").notNull(),
});

const weightRecordDeletions = sqliteTable("weight_record_deletions", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
});

// 体重記録の表。宣言は durable-object-migrations/ の SQL に合わせる（ずれはテストで気づく）
export const weightRecordTables = {
  weightRecords,
  importedWeightRecords,
  importedBodyFatPercentages,
  weightRecordDeletions,
};
