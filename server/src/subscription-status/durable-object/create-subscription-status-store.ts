import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { recordIdSchema } from "../../domain/record-id";
import { firstSignInTables } from "../../durable-object/first-sign-in-tables";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import { subscriptionTables } from "../../subscription/durable-object/subscription-tables";
import type { SubscriptionStatusStore } from "../domain/subscription-status-store";

const { firstSignIns } = firstSignInTables;
const { recordChanges } = syncLedgerTables;
const {
  appStoreSubscriptions,
  subscriptionTransactions,
  appStoreSubscriptionTransactions,
  subscriptionTransactionRevocations,
  subscriptionTransactionRevocationReversals,
  subscriptionBillingFailures,
  subscriptionGracePeriods,
  freeTrialExclusions,
} = subscriptionTables;

// テストユーザーの旗（D1）と課金を入れた日（Worker の環境変数）は、Durable Object の外から読んで渡す
export const createSubscriptionStatusStore = (
  db: DrizzleSqliteDODatabase,
  account: { isTestUser: boolean; billingStartedOn: string },
): SubscriptionStatusStore => ({
  hasRecordedChange: () =>
    db
      .select({ sequence: recordChanges.sequence })
      .from(recordChanges)
      .where(eq(recordChanges.recordType, "subscription_status"))
      .limit(1)
      .get() !== undefined,
  findFacts: () => {
    const firstSignIn = db
      .select({ id: firstSignIns.id, startedOn: firstSignIns.startedOn })
      .from(firstSignIns)
      .get();
    if (firstSignIn === undefined) {
      return undefined;
    }
    const exclusion = db
      .select({ firstSignInId: freeTrialExclusions.firstSignInId })
      .from(freeTrialExclusions)
      .where(eq(freeTrialExclusions.firstSignInId, firstSignIn.id))
      .get();
    // 課金の表は1人分の行が月に1つほどしか増えないので、全部を読んでから取引ごとに分ける
    const revocations = db
      .select({
        subscriptionTransactionId: subscriptionTransactionRevocations.subscriptionTransactionId,
        reversalId: subscriptionTransactionRevocationReversals.subscriptionTransactionRevocationId,
      })
      .from(subscriptionTransactionRevocations)
      .leftJoin(
        subscriptionTransactionRevocationReversals,
        eq(
          subscriptionTransactionRevocationReversals.subscriptionTransactionRevocationId,
          subscriptionTransactionRevocations.id,
        ),
      )
      .all();
    const gracePeriods = db
      .select({
        subscriptionTransactionId: subscriptionBillingFailures.subscriptionTransactionId,
        gracePeriodExpiresAt: subscriptionGracePeriods.gracePeriodExpiresAt,
      })
      .from(subscriptionGracePeriods)
      .innerJoin(
        subscriptionBillingFailures,
        eq(subscriptionBillingFailures.id, subscriptionGracePeriods.subscriptionBillingFailureId),
      )
      .all();
    const transactions = db
      .select({
        id: subscriptionTransactions.id,
        expiresAt: subscriptionTransactions.expiresAt,
        appStoreProductId: appStoreSubscriptionTransactions.appStoreProductId,
        environment: appStoreSubscriptions.environment,
      })
      .from(subscriptionTransactions)
      .innerJoin(
        appStoreSubscriptionTransactions,
        eq(appStoreSubscriptionTransactions.subscriptionTransactionId, subscriptionTransactions.id),
      )
      .innerJoin(
        appStoreSubscriptions,
        eq(appStoreSubscriptions.subscriptionId, subscriptionTransactions.subscriptionId),
      )
      .all();
    return {
      firstSignInId: recordIdSchema.parse(firstSignIn.id),
      startedOn: firstSignIn.startedOn,
      billingStartedOn: account.billingStartedOn,
      isTestUser: account.isTestUser,
      isExcludedByEarlierAccount: exclusion !== undefined,
      transactions: transactions.map(({ id, expiresAt, appStoreProductId, environment }) => ({
        environment,
        appStoreProductId,
        expiresAt,
        revocations: revocations
          .filter(({ subscriptionTransactionId }) => subscriptionTransactionId === id)
          .map(({ reversalId }) => ({ reversed: reversalId !== null })),
        gracePeriodExpiresAts: gracePeriods
          .filter(({ subscriptionTransactionId }) => subscriptionTransactionId === id)
          .map(({ gracePeriodExpiresAt }) => gracePeriodExpiresAt),
      })),
    };
  },
});
