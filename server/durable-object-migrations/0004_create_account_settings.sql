CREATE TABLE account_settings (
  id TEXT PRIMARY KEY,
  sends_usage_data INTEGER NOT NULL
);

CREATE TABLE account_setting_changes (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id),
  sends_usage_data INTEGER NOT NULL
);
