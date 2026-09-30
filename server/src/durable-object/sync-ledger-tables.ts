import { index, integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";

const syncRequestLogs = sqliteTable(
  "sync_request_logs",
  {
    id: text("id").primaryKey(),
    deviceId: text("device_id").notNull(),
    receivedAt: integer("received_at", { mode: "timestamp_ms" }).notNull(),
    timeZone: text("time_zone").notNull(),
    appVersion: text("app_version").notNull(),
    osVersion: text("os_version").notNull(),
    pendingWriteCount: integer("pending_write_count").notNull(),
    oldestPendingWriteAgeSeconds: integer("oldest_pending_write_age_seconds"),
    pendingPhotoCount: integer("pending_photo_count").notNull(),
  },
  (table) => [index("sync_request_logs_received_at").on(table.receivedAt)],
);

const syncPushLogs = sqliteTable("sync_push_logs", {
  syncRequestLogId: text("sync_request_log_id")
    .primaryKey()
    .references(() => syncRequestLogs.id),
  isFinalBatch: integer("is_final_batch", { mode: "boolean" }).notNull(),
});

const syncPullLogs = sqliteTable("sync_pull_logs", {
  syncRequestLogId: text("sync_request_log_id")
    .primaryKey()
    .references(() => syncRequestLogs.id),
  afterChangeSequence: integer("after_change_sequence").notNull(),
});

const syncWriteReceipts = sqliteTable(
  "sync_write_receipts",
  {
    id: text("id").primaryKey(),
    syncRequestLogId: text("sync_request_log_id")
      .notNull()
      .references(() => syncPushLogs.syncRequestLogId),
    positionInRequest: integer("position_in_request").notNull(),
    kind: text("kind", { enum: ["create", "update", "source_deleted"] }).notNull(),
    recordType: text("record_type", { enum: ["weight_record", "account_settings"] }).notNull(),
    recordId: text("record_id").notNull(),
    result: text("result", {
      enum: ["applied", "ignored_duplicate", "ignored_tombstone", "kept_corrected", "rejected"],
    }).notNull(),
  },
  (table) => [
    uniqueIndex("sync_write_receipts_position").on(table.syncRequestLogId, table.positionInRequest),
    index("sync_write_receipts_record").on(table.recordType, table.recordId),
  ],
);

const syncWriteRejections = sqliteTable("sync_write_rejections", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncWriteReceipts.id),
  reason: text("reason", {
    enum: [
      "out_of_range",
      "invalid_time_zone",
      "version_too_low",
      "record_not_found",
      "record_before_started_on",
    ],
  }).notNull(),
});

const recordChanges = sqliteTable("record_changes", {
  sequence: integer("sequence").primaryKey({ autoIncrement: true }),
  recordType: text("record_type", { enum: ["weight_record", "account_settings"] }).notNull(),
  recordId: text("record_id").notNull(),
});

const syncWriteRecordChanges = sqliteTable(
  "sync_write_record_changes",
  {
    recordChangeSequence: integer("record_change_sequence")
      .primaryKey()
      .references(() => recordChanges.sequence),
    syncWriteReceiptId: text("sync_write_receipt_id")
      .notNull()
      .references(() => syncWriteReceipts.id),
  },
  (table) => [uniqueIndex("sync_write_record_changes_receipt").on(table.syncWriteReceiptId)],
);

// 帳簿の表（要求の控え、書き込みの控え、変更の並び）。宣言は durable-object-migrations/ の SQL に合わせる
export const syncLedgerTables = {
  syncRequestLogs,
  syncPushLogs,
  syncPullLogs,
  syncWriteReceipts,
  syncWriteRejections,
  recordChanges,
  syncWriteRecordChanges,
};
