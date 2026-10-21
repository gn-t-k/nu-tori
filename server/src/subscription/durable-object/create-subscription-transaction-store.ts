import { and, eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { SubscriptionTransactionStore } from "../domain/subscription-transaction-store";
import { subscriptionTables } from "./subscription-tables";

const {
  subscriptionReceipts,
  subscriptions,
  appStoreSubscriptions,
  subscriptionTransactions,
  appStoreSubscriptionTransactions,
  subscriptionTransactionReportReceipts,
} = subscriptionTables;

// 親の行を先に書く（外部キーが指す行が先）
export const createSubscriptionTransactionStore = (
  db: DrizzleSqliteDODatabase,
): SubscriptionTransactionStore => ({
  hasReceipt: (id) =>
    db
      .select({ id: subscriptionReceipts.id })
      .from(subscriptionReceipts)
      .where(eq(subscriptionReceipts.id, id))
      .get() !== undefined,
  insertReceipt: (receipt) => {
    db.insert(subscriptionReceipts).values(receipt).run();
  },
  findAppStoreSubscriptionId: ({ environment, appStoreOriginalTransactionId }) =>
    db
      .select({ subscriptionId: appStoreSubscriptions.subscriptionId })
      .from(appStoreSubscriptions)
      .where(
        and(
          eq(appStoreSubscriptions.environment, environment),
          eq(appStoreSubscriptions.appStoreOriginalTransactionId, appStoreOriginalTransactionId),
        ),
      )
      .get()?.subscriptionId,
  insertAppStoreSubscription: ({ id, environment, appStoreOriginalTransactionId }) => {
    db.insert(subscriptions).values({ id }).run();
    db.insert(appStoreSubscriptions)
      .values({ subscriptionId: id, environment, appStoreOriginalTransactionId })
      .run();
  },
  findTransactionIdByAppStoreTransactionId: (appStoreTransactionId) =>
    db
      .select({ id: appStoreSubscriptionTransactions.subscriptionTransactionId })
      .from(appStoreSubscriptionTransactions)
      .where(eq(appStoreSubscriptionTransactions.appStoreTransactionId, appStoreTransactionId))
      .get()?.id,
  insertAppStoreTransaction: ({ appStoreTransactionId, appStoreProductId, ...transaction }) => {
    db.insert(subscriptionTransactions).values(transaction).run();
    db.insert(appStoreSubscriptionTransactions)
      .values({
        subscriptionTransactionId: transaction.id,
        appStoreTransactionId,
        appStoreProductId,
      })
      .run();
  },
  insertTransactionReportReceipt: (receipt) => {
    db.insert(subscriptionTransactionReportReceipts).values(receipt).run();
  },
});
