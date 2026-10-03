CREATE TABLE notices (
  id TEXT PRIMARY KEY,
  notice_type TEXT NOT NULL,
  issued_at INTEGER NOT NULL,
  time_zone TEXT NOT NULL
);

CREATE TABLE missed_record_notices (
  notice_id TEXT PRIMARY KEY REFERENCES notices (id) ON DELETE CASCADE,
  target_on TEXT NOT NULL
);

CREATE TABLE notice_responses (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id),
  notice_id TEXT NOT NULL REFERENCES notices (id) ON DELETE CASCADE,
  responded_at INTEGER NOT NULL,
  time_zone TEXT NOT NULL
);

CREATE UNIQUE INDEX notice_responses_notice_id ON notice_responses (notice_id);

CREATE TABLE usual_weighing_times (
  id TEXT PRIMARY KEY
);

CREATE TABLE usual_weighing_time_changes (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id),
  minute_of_day INTEGER NOT NULL
);

CREATE INDEX weight_records_measured_at ON weight_records (measured_at);
