CREATE TABLE weight_records (
  id TEXT PRIMARY KEY,
  weight_kg REAL NOT NULL,
  measured_at INTEGER NOT NULL,
  time_zone TEXT NOT NULL,
  version INTEGER NOT NULL
);

CREATE TABLE imported_weight_records (
  weight_record_id TEXT PRIMARY KEY REFERENCES weight_records (id) ON DELETE CASCADE,
  source_app_name TEXT NOT NULL,
  source_bundle_id TEXT NOT NULL,
  healthkit_sample_uuid TEXT NOT NULL
);

CREATE UNIQUE INDEX imported_weight_records_healthkit_sample_uuid
  ON imported_weight_records (healthkit_sample_uuid);

CREATE TABLE imported_body_fat_percentages (
  weight_record_id TEXT PRIMARY KEY REFERENCES imported_weight_records (weight_record_id) ON DELETE CASCADE,
  body_fat_percentage REAL NOT NULL,
  healthkit_sample_uuid TEXT NOT NULL
);

CREATE TABLE record_changes (
  sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  record_type TEXT NOT NULL,
  record_id TEXT NOT NULL
);

CREATE TABLE sync_request_logs (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  received_at INTEGER NOT NULL,
  time_zone TEXT NOT NULL,
  app_version TEXT NOT NULL,
  os_version TEXT NOT NULL,
  pending_write_count INTEGER NOT NULL,
  oldest_pending_write_age_seconds INTEGER,
  pending_photo_count INTEGER NOT NULL
);

CREATE INDEX sync_request_logs_received_at ON sync_request_logs (received_at);

CREATE TABLE sync_push_logs (
  sync_request_log_id TEXT PRIMARY KEY REFERENCES sync_request_logs (id),
  is_final_batch INTEGER NOT NULL
);

CREATE TABLE sync_pull_logs (
  sync_request_log_id TEXT PRIMARY KEY REFERENCES sync_request_logs (id),
  after_change_sequence INTEGER NOT NULL
);

CREATE TABLE sync_write_receipts (
  id TEXT PRIMARY KEY,
  sync_request_log_id TEXT NOT NULL REFERENCES sync_push_logs (sync_request_log_id),
  position_in_request INTEGER NOT NULL,
  kind TEXT NOT NULL,
  record_type TEXT NOT NULL,
  record_id TEXT NOT NULL,
  result TEXT NOT NULL
);

CREATE UNIQUE INDEX sync_write_receipts_position
  ON sync_write_receipts (sync_request_log_id, position_in_request);

CREATE INDEX sync_write_receipts_record ON sync_write_receipts (record_type, record_id);

CREATE TABLE sync_write_rejections (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id),
  reason TEXT NOT NULL
);

CREATE TABLE sync_write_record_changes (
  record_change_sequence INTEGER PRIMARY KEY REFERENCES record_changes (sequence),
  sync_write_receipt_id TEXT NOT NULL REFERENCES sync_write_receipts (id)
);

CREATE UNIQUE INDEX sync_write_record_changes_receipt
  ON sync_write_record_changes (sync_write_receipt_id);
