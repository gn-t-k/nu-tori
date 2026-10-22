import { match } from "ts-pattern";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { UsageEvent } from "../../domain/usage-event";
import { computeSubscriptionStatus } from "../../subscription-status/domain/compute-subscription-status";
import { createSubscriptionExpiredEvent } from "../../subscription-status/domain/create-subscription-expired-event";
import { findSubscriptionTimeZone } from "../../subscription-status/domain/find-subscription-time-zone";
import { isSubscriptionExpired } from "../../subscription-status/domain/is-subscription-expired";
import { readSubscriptionFacts } from "../../subscription-status/domain/read-subscription-facts";
import { computeFreeTrial } from "./compute-free-trial";
import { isWithinFreeTrial } from "./is-within-free-trial";
import type { AppStoreSubscriptionTransaction } from "./read-app-store-subscription-transaction";

// 取引の写しを書いたあと（同じトランザクションの中）に、書いた事実から利用状況の出来事を作る（#647 の「観測」）。
// - 理由が purchase の取引を書いたら始まった、renewal なら更新した
// - 取り消しを書いて、今サブスクリプション切れなら切れた
// 送るのは Production の環境の取引だけ（Sandbox は開発者と TestFlight の買い物）
export const createWrittenFactUsageEvents = (
  stores: Pick<RecordKindStores, "subscriptionStatus" | "latestTimeZone" | "firstSignIn">,
  transaction: AppStoreSubscriptionTransaction,
  written: { wroteTransaction: boolean; wroteRevocation: boolean },
  now: Date,
): UsageEvent[] => {
  if (transaction.environment !== "production") {
    return [];
  }
  const facts = readSubscriptionFacts(stores.subscriptionStatus);
  const timeZone = findSubscriptionTimeZone(stores);
  const transactionEvents: UsageEvent[] = written.wroteTransaction
    ? [
        match(transaction.transactionReason)
          .with("purchase", (): UsageEvent => ({
            name: "subscription_started",
            purchasedDuringFreeTrial: isWithinFreeTrial(
              computeFreeTrial(facts),
              computeCalendarDayInTimeZone(transaction.purchasedAt, timeZone),
            ),
            rebuiltAccount: facts.isExcludedByEarlierAccount,
          }))
          .with("renewal", (): UsageEvent => ({ name: "subscription_renewed" }))
          .exhaustive(),
      ]
    : [];
  const isExpiredByRevocation =
    written.wroteRevocation &&
    isSubscriptionExpired(computeSubscriptionStatus(facts), {
      countedOn: computeCalendarDayInTimeZone(now, timeZone),
      at: now,
    });
  return isExpiredByRevocation
    ? [...transactionEvents, createSubscriptionExpiredEvent(facts, { byRevocation: true })]
    : transactionEvents;
};
