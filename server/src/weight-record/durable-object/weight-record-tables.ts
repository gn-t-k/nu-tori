import { index, integer, real, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";

// 作ったときの値のまま、UPDATE しない。直した値は体重の修正と時刻の修正に書き足す（#977）。
// 消すのは、元のサンプルが消えたときの、直していない記録の行だけ（取り込みと体脂肪率は CASCADE で消える）。
// 例外として、#977 の移行より前に直した記録は、上書きで直す前の値を失っているので、移行の時点の今の値を持つ
const weightRecords = sqliteTable(
  "weight_records",
  {
    id: text("id").$type<RecordId>().primaryKey(),
    weightKg: real("weight_kg").notNull(),
    measuredAt: integer("measured_at", { mode: "timestamp_ms" }).notNull(),
    timeZone: text("time_zone").notNull(),
  },
  // 体重の傾向の計算と、いつもの時刻の学び直しで、時刻の順に読むため
  (table) => [index("weight_records_measured_at").on(table.measuredAt)],
);

const importedWeightRecords = sqliteTable(
  "imported_weight_records",
  {
    weightRecordId: text("weight_record_id")
      .$type<RecordId>()
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
    .$type<RecordId>()
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

// 体重の修正。体重記録は控えの record_id で指す。INSERT だけで、消えるのはアカウントを消すときだけ
const weightRecordWeightCorrections = sqliteTable("weight_record_weight_corrections", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
  weightKg: real("weight_kg").notNull(),
});

// 時刻の修正。時刻とタイムゾーンは組で「いつ測ったか」の1つの事実なので、1つの表に持つ。決まりは体重の修正と同じ
const weightRecordMeasuredAtCorrections = sqliteTable(
  "weight_record_measured_at_corrections",
  {
    syncWriteReceiptId: text("sync_write_receipt_id")
      .primaryKey()
      .references(() => syncLedgerTables.syncWriteReceipts.id),
    measuredAt: integer("measured_at", { mode: "timestamp_ms" }).notNull(),
    timeZone: text("time_zone").notNull(),
  },
  // 時刻の範囲で体重記録を読むとき、直した時刻が範囲に入る記録を候補に引くため
  (table) => [index("weight_record_measured_at_corrections_measured_at").on(table.measuredAt)],
);

// 体重記録の表。宣言は durable-object-migrations/ の SQL に合わせる（ずれはテストで気づく）
export const weightRecordTables = {
  weightRecords,
  importedWeightRecords,
  importedBodyFatPercentages,
  weightRecordDeletions,
  weightRecordWeightCorrections,
  weightRecordMeasuredAtCorrections,
};
