import { index, integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";
import { authenticationTables } from "../../auth/authentication-tables";
import { appStoreSubscriptionEnvironments } from "../domain/subscription-transaction-fact";

const { user } = authenticationTables;

// 購入者のトークン（appAccountToken）。サーバーが出し、アカウントの ID とは別の値にする
const appAccountTokens = sqliteTable(
  "app_account_tokens",
  {
    accountId: text("account_id")
      .primaryKey()
      .references(() => user.id, { onDelete: "cascade" }),
    appAccountToken: text("app_account_token").notNull(),
  },
  (table) => [uniqueIndex("app_account_tokens_app_account_token").on(table.appAccountToken)],
);

// App Store のサブスクリプションの案内。DO の app_store_subscriptions と、環境と元の取引の ID の同じ値で照らす（外部キーは無い）
const appStoreSubscriptionRoutes = sqliteTable(
  "app_store_subscription_routes",
  {
    id: text("id").primaryKey(),
    accountId: text("account_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    environment: text("environment", { enum: appStoreSubscriptionEnvironments }).notNull(),
    appStoreOriginalTransactionId: text("app_store_original_transaction_id").notNull(),
  },
  (table) => [
    uniqueIndex("app_store_subscription_routes_environment").on(
      table.environment,
      table.appStoreOriginalTransactionId,
    ),
    index("app_store_subscription_routes_account_id").on(table.accountId),
  ],
);

// 無料体験を使った Apple ID。退会のあとも残すので、どの表ともつながない
const freeTrialUsages = sqliteTable(
  "free_trial_usages",
  {
    id: text("id").primaryKey(),
    appleSubHash: text("apple_sub_hash").notNull(),
    keyVersion: integer("key_version").notNull(),
  },
  (table) => [uniqueIndex("free_trial_usages_apple_sub_hash").on(table.appleSubHash)],
);

// テストユーザー。開発者が手で行を足し、外すときは行を消す
const testUsers = sqliteTable("test_users", {
  accountId: text("account_id")
    .primaryKey()
    .references(() => user.id, { onDelete: "cascade" }),
});

// 課金の D1 の表（#647）。宣言は d1-migrations/ の SQL に合わせる
export const subscriptionD1Tables = {
  appAccountTokens,
  appStoreSubscriptionRoutes,
  freeTrialUsages,
  testUsers,
};
