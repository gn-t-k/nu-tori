-- 課金の仕様（#647）の D1 の 4 つの表と索引を足す。CREATE だけで、既存の表は変えない。
-- 全アカウントをまたいで引くもの（App Store のサーバー通知の案内）と、退会のあとも残すもの（無料体験を使った Apple ID）を置く。
-- 列名は apple_refresh_tokens と同じく snake_case。区分の値（environment）に CHECK は書かない

-- 購入者のトークン（appAccountToken）。アカウントの ID とは別の値にする
CREATE TABLE app_account_tokens (
  account_id TEXT NOT NULL PRIMARY KEY REFERENCES "user" ("id") ON DELETE CASCADE,
  app_account_token TEXT NOT NULL
);

CREATE UNIQUE INDEX app_account_tokens_app_account_token ON app_account_tokens (app_account_token);

-- App Store のサブスクリプションの案内。環境と元の取引の ID の組で、最初に結びついたアカウントのもの
CREATE TABLE app_store_subscription_routes (
  id TEXT NOT NULL PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  environment TEXT NOT NULL,
  app_store_original_transaction_id TEXT NOT NULL
);

CREATE UNIQUE INDEX app_store_subscription_routes_environment
  ON app_store_subscription_routes (environment, app_store_original_transaction_id);

CREATE INDEX app_store_subscription_routes_account_id ON app_store_subscription_routes (account_id);

-- 無料体験を使った Apple ID（sub の鍵付きハッシュ）。外部キーも日時も持たず、退会のあとも残す
CREATE TABLE free_trial_usages (
  id TEXT NOT NULL PRIMARY KEY,
  apple_sub_hash TEXT NOT NULL,
  key_version INTEGER NOT NULL
);

CREATE UNIQUE INDEX free_trial_usages_apple_sub_hash ON free_trial_usages (apple_sub_hash);

-- テストユーザー。開発者が wrangler d1 execute で行を足し、外すときは行を消す（書き足すだけの決まりの例外）
CREATE TABLE test_users (
  account_id TEXT NOT NULL PRIMARY KEY REFERENCES "user" ("id") ON DELETE CASCADE
);
