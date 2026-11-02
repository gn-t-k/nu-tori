import { findEarliest } from "../../../domain/find-earliest";
import { computeSubscriptionBoundaries } from "../compute-subscription-boundaries";
import { hasPassedWithinDay } from "../has-passed-within-day";
import type { SubscriptionStatusFacts } from "../subscription-status-store";

// 課金の仕事（アラーム）が動く時刻。切れた出来事を送るため、無料体験の終わり（最後の日の次の日の始まり）とサブスクリプションの終わりのうち、今より後のいちばん早いものが nextAt。isDue は、そのどれかを過ぎてから 24 時間の内か。
export const findSubscriptionCheck = (
  facts: Omit<SubscriptionStatusFacts, "firstSignInId" | "isTestUser">,
  timeZone: string,
  now: Date,
): { nextAt: Date | undefined; isDue: boolean } => {
  const { freeTrialEnd, subscriptionEnd } = computeSubscriptionBoundaries(facts, timeZone);
  const times = [freeTrialEnd, subscriptionEnd];
  return {
    nextAt: findEarliest(times.filter((time) => time !== undefined && time > now)),
    isDue: times.some((time) => hasPassedWithinDay(time, now)),
  };
};
