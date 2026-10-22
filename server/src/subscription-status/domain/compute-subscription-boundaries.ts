import { match } from "ts-pattern";
import { addDays } from "../../domain/add-days";
import { computeNextDayStart } from "../../estimation/domain/compute-next-day-start";
import { computeFreeTrial } from "../../subscription/domain/compute-free-trial";
import { computeSubscription } from "../../subscription/domain/compute-subscription";
import { computeSubscriptionEnd } from "../../subscription/domain/compute-subscription-end";
import type { SubscriptionStatusFacts } from "./subscription-status-store";

// 無料体験とサブスクリプションの区切りの時刻。日の始まりは timeZone（findSubscriptionTimeZone で選ぶ）で出す。
// 無料体験は、あと3日の日・最後の日・終わり（最後の日の次の日）の始まり。作り直したアカウントには無い
export const computeSubscriptionBoundaries = (
  facts: Omit<SubscriptionStatusFacts, "firstSignInId" | "isTestUser">,
  timeZone: string,
): {
  freeTrial: { threeDaysLeftAt: Date; lastDayAt: Date; endsAt: Date } | undefined;
  subscriptionEnd: Date | undefined;
} => {
  const startOfDay = (calendarDay: string) =>
    computeNextDayStart(addDays(calendarDay, -1), timeZone).startsAt;
  return {
    freeTrial: match(computeFreeTrial(facts))
      .with({ type: "available" }, ({ lastDay }) => ({
        threeDaysLeftAt: startOfDay(addDays(lastDay, -2)),
        lastDayAt: startOfDay(lastDay),
        endsAt: startOfDay(addDays(lastDay, 1)),
      }))
      .with({ type: "used_by_earlier_account" }, () => undefined)
      .exhaustive(),
    subscriptionEnd: computeSubscriptionEnd(computeSubscription(facts.transactions)),
  };
};
