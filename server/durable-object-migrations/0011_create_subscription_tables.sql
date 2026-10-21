-- 課金の仕様（#647）の 15 の表と 3 つの一意の索引を足す。CREATE だけで、既存の表は変えない。
-- 既存の列に足す区分の値（帳簿の record_type の subscription_status、deferred_weekly_reviews.reason の subscription_expired）は、
-- 列に CHECK が無いので SQL の移行は要らない（#647 の Schema changes）。
-- どの表も書き足すだけで、UPDATE も DELETE も無い。外部キーは既存の first_sign_ins（0001）・estimation_schedules（0005）・
-- reply_requests（0008）と、この移行の表だけを指す。親の表は消さないので ON DELETE は付けない。
-- 課金の表は1人分の行が月に1つほどしか増えないので、外部キーの列の索引は置かない。索引の名前は先頭の列で名付ける

-- 受け取り（事実の表が、その行を書いた受け取りを指すので先に作る）

CREATE TABLE subscription_receipts (
  id TEXT PRIMARY KEY,
  received_at INTEGER NOT NULL
);

-- サブスクリプションと取引

CREATE TABLE subscriptions (
  id TEXT PRIMARY KEY
);

CREATE TABLE app_store_subscriptions (
  subscription_id TEXT PRIMARY KEY REFERENCES subscriptions (id),
  environment TEXT NOT NULL,
  app_store_original_transaction_id TEXT NOT NULL
);

CREATE UNIQUE INDEX app_store_subscriptions_environment
  ON app_store_subscriptions (environment, app_store_original_transaction_id);

CREATE TABLE subscription_transactions (
  id TEXT PRIMARY KEY,
  subscription_id TEXT NOT NULL REFERENCES subscriptions (id),
  subscription_receipt_id TEXT NOT NULL REFERENCES subscription_receipts (id),
  transaction_reason TEXT NOT NULL,
  purchased_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE TABLE app_store_subscription_transactions (
  subscription_transaction_id TEXT PRIMARY KEY REFERENCES subscription_transactions (id),
  app_store_transaction_id TEXT NOT NULL,
  app_store_product_id TEXT NOT NULL
);

CREATE UNIQUE INDEX app_store_subscription_transactions_app_store_transaction_id
  ON app_store_subscription_transactions (app_store_transaction_id);

CREATE TABLE subscription_transaction_revocations (
  id TEXT PRIMARY KEY,
  subscription_transaction_id TEXT NOT NULL REFERENCES subscription_transactions (id),
  subscription_receipt_id TEXT NOT NULL REFERENCES subscription_receipts (id),
  revoked_at INTEGER NOT NULL
);

CREATE TABLE subscription_transaction_revocation_reversals (
  subscription_transaction_revocation_id TEXT PRIMARY KEY
    REFERENCES subscription_transaction_revocations (id),
  subscription_receipt_id TEXT NOT NULL REFERENCES subscription_receipts (id),
  reversed_at INTEGER NOT NULL
);

CREATE TABLE subscription_billing_failures (
  id TEXT PRIMARY KEY,
  subscription_transaction_id TEXT NOT NULL REFERENCES subscription_transactions (id),
  subscription_receipt_id TEXT NOT NULL REFERENCES subscription_receipts (id),
  failed_at INTEGER NOT NULL
);

CREATE TABLE subscription_grace_periods (
  subscription_billing_failure_id TEXT PRIMARY KEY REFERENCES subscription_billing_failures (id),
  grace_period_expires_at INTEGER NOT NULL
);

-- 受け取りの種類

CREATE TABLE app_store_notification_receipts (
  subscription_receipt_id TEXT PRIMARY KEY REFERENCES subscription_receipts (id),
  subscription_id TEXT NOT NULL REFERENCES app_store_subscriptions (subscription_id),
  notification_uuid TEXT NOT NULL,
  notification_type TEXT NOT NULL,
  notification_subtype TEXT
);

CREATE UNIQUE INDEX app_store_notification_receipts_notification_uuid
  ON app_store_notification_receipts (notification_uuid);

CREATE TABLE subscription_transaction_report_receipts (
  subscription_receipt_id TEXT PRIMARY KEY REFERENCES subscription_receipts (id),
  subscription_transaction_id TEXT NOT NULL
    REFERENCES app_store_subscription_transactions (subscription_transaction_id),
  report_trigger TEXT NOT NULL
);

-- 既存の表につなぐもの

CREATE TABLE free_trial_exclusions (
  first_sign_in_id TEXT PRIMARY KEY REFERENCES first_sign_ins (id)
);

CREATE TABLE estimation_holds (
  estimation_schedule_id TEXT PRIMARY KEY REFERENCES estimation_schedules (id),
  held_at INTEGER NOT NULL
);

CREATE TABLE reply_request_subscription_halts (
  reply_request_id TEXT PRIMARY KEY REFERENCES reply_requests (id),
  halted_at INTEGER NOT NULL
);

CREATE TABLE terms_agreements (
  id TEXT PRIMARY KEY,
  terms_version TEXT NOT NULL,
  agreement_screen TEXT NOT NULL,
  agreed_at INTEGER NOT NULL
);
