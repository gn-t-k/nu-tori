CREATE TABLE weight_record_deletions (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id)
);
