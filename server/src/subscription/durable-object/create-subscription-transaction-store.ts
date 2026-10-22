import { and, eq, isNull } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { SubscriptionTransactionStore } from "../domain/subscription-transaction-store";
import { subscriptionTables } from "./subscription-tables";

const {
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
  hasRevocationAt: (subscriptionTransactionId, revokedAt) =>
    db
      .select({ id: subscriptionTransactionRevocations.id })
      .from(subscriptionTransactionRevocations)
      .where(
        and(
          eq(
            subscriptionTransactionRevocations.subscriptionTransactionId,
            subscriptionTransactionId,
          ),
          eq(subscriptionTransactionRevocations.revokedAt, revokedAt),
        ),
      )
      .get() !== undefined,
  insertRevocation: (revocation) => {
    db.insert(subscriptionTransactionRevocations).values(revocation).run();
  },
  findUnreversedRevocationIds: (subscriptionTransactionId) =>
    db
      .select({ id: subscriptionTransactionRevocations.id })
      .from(subscriptionTransactionRevocations)
      .leftJoin(
        subscriptionTransactionRevocationReversals,
        eq(
          subscriptionTransactionRevocationReversals.subscriptionTransactionRevocationId,
          subscriptionTransactionRevocations.id,
        ),
      )
      .where(
        and(
          eq(
            subscriptionTransactionRevocations.subscriptionTransactionId,
            subscriptionTransactionId,
          ),
          isNull(subscriptionTransactionRevocationReversals.subscriptionTransactionRevocationId),
        ),
      )
      .all()
      .map(({ id }) => id),
  insertRevocationReversal: (reversal) => {
    db.insert(subscriptionTransactionRevocationReversals).values(reversal).run();
  },
  insertBillingFailure: ({ gracePeriodExpiresAt, ...failure }) => {
    db.insert(subscriptionBillingFailures).values(failure).run();
    if (gracePeriodExpiresAt !== undefined) {
      db.insert(subscriptionGracePeriods)
        .values({ subscriptionBillingFailureId: failure.id, gracePeriodExpiresAt })
        .run();
    }
  },
  hasNotificationReceipt: (notificationUuid) =>
    db
      .select({ id: appStoreNotificationReceipts.subscriptionReceiptId })
      .from(appStoreNotificationReceipts)
      .where(eq(appStoreNotificationReceipts.notificationUuid, notificationUuid))
      .get() !== undefined,
  insertNotificationReceipt: ({ notificationSubtype, ...receipt }) => {
    db.insert(appStoreNotificationReceipts)
      .values({ ...receipt, notificationSubtype: notificationSubtype ?? null })
      .run();
  },
  insertTransactionReportReceipt: (receipt) => {
    db.insert(subscriptionTransactionReportReceipts).values(receipt).run();
  },
});
