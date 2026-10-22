import { findEarliest } from "../../../domain/find-earliest";
import { computeSubscriptionBoundaries } from "../compute-subscription-boundaries";
import { hasPassedWithinDay } from "../has-passed-within-day";
import type { SubscriptionStatusFacts } from "../subscription-status-store";

// 課金の仕事（アラーム）が動く時刻。あと3日の日の始まり・最後の日の始まり・無料体験の終わり（最後の日の次の日の始まり）・
// サブスクリプションの終わりのうち、今より後のいちばん早いものが nextAt。isDue は、そのどれかを過ぎてから 24 時間の内か。
// テストユーザーの旗によらず、無料体験とサブスクリプションの事実から出す（旗を外したときに届けるため）
export const findSubscriptionCheck = (
  facts: Omit<SubscriptionStatusFacts, "firstSignInId" | "isTestUser">,
  timeZone: string,
  now: Date,
): { nextAt: Date | undefined; isDue: boolean } => {
  const { freeTrial, subscriptionEnd } = computeSubscriptionBoundaries(facts, timeZone);
  const times = [
    freeTrial?.threeDaysLeftAt,
    freeTrial?.lastDayAt,
    freeTrial?.endsAt,
    subscriptionEnd,
  ];
  return {
    nextAt: findEarliest(times.filter((time) => time !== undefined && time > now)),
    isDue: times.some((time) => hasPassedWithinDay(time, now)),
  };
};
