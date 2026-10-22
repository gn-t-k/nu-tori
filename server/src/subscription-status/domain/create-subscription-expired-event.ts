import type { UsageEvent } from "../../domain/usage-event";
import type { SubscriptionStatusFacts } from "./subscription-status-store";

// サブスクリプション切れになったときの出来事（#647 の「観測」）。切れたかとテストユーザーかは呼ぶ側が確かめる
export const createSubscriptionExpiredEvent = (
  facts: Pick<SubscriptionStatusFacts, "transactions" | "isExcludedByEarlierAccount">,
  { byRevocation }: { byRevocation: boolean },
): UsageEvent => ({
  name: "subscription_expired",
  hasPurchased: facts.transactions.length > 0,
  byRevocation,
  rebuiltAccount: facts.isExcludedByEarlierAccount,
});
