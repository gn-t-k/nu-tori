import { match } from "ts-pattern";
import type { UsageEvent } from "../../domain/usage-event";
import { computeNextDayStart } from "../../estimation/domain/compute-next-day-start";
import { computeFreeTrial } from "../../subscription/domain/compute-free-trial";
import { computeSubscription } from "../../subscription/domain/compute-subscription";
import { computeSubscriptionEnd } from "../../subscription/domain/compute-subscription-end";
import { createSubscriptionExpiredEvent } from "./create-subscription-expired-event";
import type { SubscriptionStatusFacts } from "./subscription-status-store";

// 課金の仕事のアラームで送る、切れた出来事（#647 の「観測」の subscription_expired の (1)）。
// 使える終わり（取引があればサブスクリプションの終わりと無料体験の終わりの遅いほう、無ければ無料体験の終わり）が
// 今より前の 24 時間の内にあれば、今はサブスクリプション切れなので送る。テストユーザーと、取引がすべて Sandbox の
// アカウント（開発者と TestFlight の買い物）には送らない。24 時間の内にほかの仕事でアラームが動くと2度送るのを受け入れる
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
  const freeTrialEnd = match(computeFreeTrial(facts))
    .with({ type: "available" }, ({ lastDay }) => computeNextDayStart(lastDay, timeZone).startsAt)
    .with({ type: "used_by_earlier_account" }, () => undefined)
    .exhaustive();
  const subscriptionEnd = computeSubscriptionEnd(computeSubscription(facts.transactions));
  const accessEnd =
    subscriptionEnd === undefined || (freeTrialEnd !== undefined && freeTrialEnd > subscriptionEnd)
      ? freeTrialEnd
      : subscriptionEnd;
  if (
    accessEnd === undefined ||
    accessEnd.getTime() > now.getTime() ||
    now.getTime() - accessEnd.getTime() >= expiredWindowMs
  ) {
    return undefined;
  }
  return createSubscriptionExpiredEvent(facts, { byRevocation: false });
};

const expiredWindowMs = 24 * 60 * 60 * 1000;
