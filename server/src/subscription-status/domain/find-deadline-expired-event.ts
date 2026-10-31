import type { UsageEvent } from "../../domain/usage-event";
import { computeSubscriptionBoundaries } from "./compute-subscription-boundaries";
import { createSubscriptionExpiredEvent } from "./create-subscription-expired-event";
import { hasPassedWithinDay } from "./has-passed-within-day";
import type { SubscriptionStatusFacts } from "./subscription-status-store";

// 課金の仕事のアラームで送る、切れた出来事（#647 の「観測」の subscription_expired の (1)）。
// 使える終わり（取引があればサブスクリプションの終わりと無料体験の終わりの遅いほう、無ければ無料体験の終わり）が今より前の 24 時間の内にあれば、今はサブスクリプション切れなので送る。テストユーザーと、取引がすべて Sandbox のアカウント（開発者と TestFlight の買い物）には送らない
export const findDeadlineExpiredEvent = (
  facts: SubscriptionStatusFacts,
  timeZone: string,
  now: Date,
): UsageEvent | undefined => {
  if (
    facts.isTestUser ||
    (facts.transactions.length > 0 &&
      facts.transactions.every(({ environment }) => environment === "sandbox"))
  ) {
    return undefined;
  }
  const { freeTrial, subscriptionEnd } = computeSubscriptionBoundaries(facts, timeZone);
  const freeTrialEnd = freeTrial?.endsAt;
  const accessEnd =
    subscriptionEnd === undefined || (freeTrialEnd !== undefined && freeTrialEnd > subscriptionEnd)
      ? freeTrialEnd
      : subscriptionEnd;
  return hasPassedWithinDay(accessEnd, now)
    ? createSubscriptionExpiredEvent(facts, { byRevocation: false })
    : undefined;
};
