import { match } from "ts-pattern";
import { computeNextDayStart } from "../../estimation/domain/compute-next-day-start";
import { computeFreeTrial } from "../../subscription/domain/compute-free-trial";
import { computeSubscription } from "../../subscription/domain/compute-subscription";
import { computeSubscriptionEnd } from "../../subscription/domain/compute-subscription-end";
import type { SubscriptionStatusFacts } from "./subscription-status-store";

// 無料体験とサブスクリプションの区切りの時刻。日の始まりは timeZone（findSubscriptionTimeZone で選ぶ）で出す。
// 無料体験の終わりは、最後の日の次の日の始まり。作り直したアカウントには無い
export const computeSubscriptionBoundaries = (
  facts: Omit<SubscriptionStatusFacts, "firstSignInId" | "isTestUser">,
  timeZone: string,
): {
  freeTrialEnd: Date | undefined;
  subscriptionEnd: Date | undefined;
} => {
  return {
    freeTrialEnd: match(computeFreeTrial(facts))
      .with({ type: "available" }, ({ lastDay }) => computeNextDayStart(lastDay, timeZone).startsAt)
      .with({ type: "used_by_earlier_account" }, () => undefined)
      .exhaustive(),
    subscriptionEnd: computeSubscriptionEnd(computeSubscription(facts.transactions)),
  };
};
