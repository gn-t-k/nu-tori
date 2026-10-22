import { integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { firstSignInTables } from "../../durable-object/first-sign-in-tables";
import {
  appStoreSubscriptionEnvironments,
  subscriptionTransactionReasons,
  subscriptionTransactionReportTriggers,
} from "../domain/subscription-transaction-fact";

// 受け取りの親。端末からの知らせでは端末が振った要求の ID、App Store のサーバー通知ではサーバーが出す UUID。
// 種類はどのサブセットに行があるかで表す
const subscriptionReceipts = sqliteTable("subscription_receipts", {
  id: text("id").$type<RecordId>().primaryKey(),
  receivedAt: integer("received_at", { mode: "timestamp_ms" }).notNull(),
});

// 出どころはどのサブセットに行があるかで表す。最初の取引の行と同じトランザクションで書く
const subscriptions = sqliteTable("subscriptions", {
  id: text("id").$type<RecordId>().primaryKey(),
});

// App Store の出どころ。環境はここにだけ持つ
const appStoreSubscriptions = sqliteTable(
  "app_store_subscriptions",
  {
    subscriptionId: text("subscription_id")
      .$type<RecordId>()
      .primaryKey()
      .references(() => subscriptions.id),
    environment: text("environment", { enum: appStoreSubscriptionEnvironments }).notNull(),
    appStoreOriginalTransactionId: text("app_store_original_transaction_id").notNull(),
  },
  (table) => [
    uniqueIndex("app_store_subscriptions_environment").on(
      table.environment,
      table.appStoreOriginalTransactionId,
    ),
  ],
);

// 取引。同じ取引の写しが何度届いても、最初の写しで1度だけ書く。subscription_receipt_id はこの行を書いた受け取り
const subscriptionTransactions = sqliteTable("subscription_transactions", {
  id: text("id").$type<RecordId>().primaryKey(),
  subscriptionId: text("subscription_id")
    .$type<RecordId>()
    .notNull()
    .references(() => subscriptions.id),
  subscriptionReceiptId: text("subscription_receipt_id")
    .$type<RecordId>()
    .notNull()
    .references(() => subscriptionReceipts.id),
  transactionReason: text("transaction_reason", { enum: subscriptionTransactionReasons }).notNull(),
  purchasedAt: integer("purchased_at", { mode: "timestamp_ms" }).notNull(),
  expiresAt: integer("expires_at", { mode: "timestamp_ms" }).notNull(),
});

const appStoreSubscriptionTransactions = sqliteTable(
  "app_store_subscription_transactions",
  {
    subscriptionTransactionId: text("subscription_transaction_id")
      .$type<RecordId>()
      .primaryKey()
      .references(() => subscriptionTransactions.id),
    appStoreTransactionId: text("app_store_transaction_id").notNull(),
    appStoreProductId: text("app_store_product_id").notNull(),
  },
  (table) => [
    uniqueIndex("app_store_subscription_transactions_app_store_transaction_id").on(
      table.appStoreTransactionId,
    ),
  ],
);

// 取り消し。戻したあとにまた取り消されたら、取り消しの時刻が違う新しい行を足す
const subscriptionTransactionRevocations = sqliteTable("subscription_transaction_revocations", {
  id: text("id").$type<RecordId>().primaryKey(),
  subscriptionTransactionId: text("subscription_transaction_id")
    .$type<RecordId>()
    .notNull()
    .references(() => subscriptionTransactions.id),
  subscriptionReceiptId: text("subscription_receipt_id")
    .$type<RecordId>()
    .notNull()
    .references(() => subscriptionReceipts.id),
  revokedAt: integer("revoked_at", { mode: "timestamp_ms" }).notNull(),
});

// 取り消しの戻し。reversed_at は通知の signedDate
const subscriptionTransactionRevocationReversals = sqliteTable(
  "subscription_transaction_revocation_reversals",
  {
    subscriptionTransactionRevocationId: text("subscription_transaction_revocation_id")
      .$type<RecordId>()
      .primaryKey()
      .references(() => subscriptionTransactionRevocations.id),
    subscriptionReceiptId: text("subscription_receipt_id")
      .$type<RecordId>()
      .notNull()
      .references(() => subscriptionReceipts.id),
    reversedAt: integer("reversed_at", { mode: "timestamp_ms" }).notNull(),
  },
);

// 更新の請求の失敗。取引は、失敗した更新の前の期間のもの。failed_at は通知の signedDate
const subscriptionBillingFailures = sqliteTable("subscription_billing_failures", {
  id: text("id").$type<RecordId>().primaryKey(),
  subscriptionTransactionId: text("subscription_transaction_id")
    .$type<RecordId>()
    .notNull()
    .references(() => subscriptionTransactions.id),
  subscriptionReceiptId: text("subscription_receipt_id")
    .$type<RecordId>()
    .notNull()
    .references(() => subscriptionReceipts.id),
  failedAt: integer("failed_at", { mode: "timestamp_ms" }).notNull(),
});

const subscriptionGracePeriods = sqliteTable("subscription_grace_periods", {
  subscriptionBillingFailureId: text("subscription_billing_failure_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => subscriptionBillingFailures.id),
  gracePeriodExpiresAt: integer("grace_period_expires_at", { mode: "timestamp_ms" }).notNull(),
});

// App Store のサーバー通知の受け取り。何も書かなかった通知も、どのサブスクリプションのものか分かる。
// 通知の種類は Apple が足していくので、区分の一覧で縛らない
const appStoreNotificationReceipts = sqliteTable(
  "app_store_notification_receipts",
  {
    subscriptionReceiptId: text("subscription_receipt_id")
      .$type<RecordId>()
      .primaryKey()
      .references(() => subscriptionReceipts.id),
    subscriptionId: text("subscription_id")
      .$type<RecordId>()
      .notNull()
      .references(() => appStoreSubscriptions.subscriptionId),
    notificationUuid: text("notification_uuid").notNull(),
    notificationType: text("notification_type").notNull(),
    // subtype の無い通知があるので、この表でだけ NULL を許す
    notificationSubtype: text("notification_subtype"),
  },
  (table) => [
    uniqueIndex("app_store_notification_receipts_notification_uuid").on(table.notificationUuid),
  ],
);

// 端末からの取引の知らせの受け取り。運んだ App Store の取引を指す
const subscriptionTransactionReportReceipts = sqliteTable(
  "subscription_transaction_report_receipts",
  {
    subscriptionReceiptId: text("subscription_receipt_id")
      .$type<RecordId>()
      .primaryKey()
      .references(() => subscriptionReceipts.id),
    subscriptionTransactionId: text("subscription_transaction_id")
      .$type<RecordId>()
      .notNull()
      .references(() => appStoreSubscriptionTransactions.subscriptionTransactionId),
    reportTrigger: text("report_trigger", {
      enum: subscriptionTransactionReportTriggers,
    }).notNull(),
  },
);

// 無料体験なし（作り直したアカウント）
const freeTrialExclusions = sqliteTable("free_trial_exclusions", {
  firstSignInId: text("first_sign_in_id")
    .primaryKey()
    .references(() => firstSignInTables.firstSignIns.id),
});

// 課金の表（#647）。どの表も書き足すだけ。宣言は durable-object-migrations/ の SQL に合わせる。
// 推定の保留は推定の表の束、返事のサブスクリプション切れの止めは返事の表の束、規約への同意は規約への同意の表の束に置く
export const subscriptionTables = {
  subscriptionReceipts,
  subscriptions,
  appStoreSubscriptions,
  subscriptionTransactions,
  appStoreSubscriptionTransactions,
  subscriptionTransactionRevocations,
  subscriptionTransactionRevocationReversals,
  subscriptionBillingFailures,
  subscriptionGracePeriods,
  appStoreNotificationReceipts,
  subscriptionTransactionReportReceipts,
  freeTrialExclusions,
};
