import { match } from "ts-pattern";
import { addDays } from "../../../domain/add-days";
import { findEarliest } from "../../../domain/find-earliest";
import { computeNextDayStart } from "../../../estimation/domain/compute-next-day-start";
import { computeFreeTrial } from "../../../subscription/domain/compute-free-trial";
import { computeSubscription } from "../../../subscription/domain/compute-subscription";
import { computeSubscriptionEnd } from "../../../subscription/domain/compute-subscription-end";
import type { SubscriptionStatusFacts } from "../subscription-status-store";

// 課金の仕事（アラーム）が動く時刻。あと3日の日の始まり・最後の日の始まり・無料体験の終わり（最後の日の次の日の始まり）・
// サブスクリプションの終わりのうち、今より後のいちばん早いものが nextAt。
// isDue は、そのどれかを過ぎてから 24 時間の内か（アラームはその時刻に動くので、ほかの仕事で動いたアラームと見分ける。
// 24 時間の内に別のアラームが動くと2度目になるのを受け入れる）。
// 日の始まりは、最新の読めるタイムゾーン、無ければ最初のサインインのタイムゾーン、それも無ければ UTC で出す。
// テストユーザーの旗によらず、無料体験とサブスクリプションの事実から出す（旗を外したときに届けるため）
export const findSubscriptionCheck = (
  facts: Omit<SubscriptionStatusFacts, "firstSignInId" | "isTestUser">,
  timeZones: { latest: string | undefined; firstSignIn: string | undefined },
  now: Date,
): { nextAt: Date | undefined; isDue: boolean } => {
  const timeZone = timeZones.latest ?? timeZones.firstSignIn ?? "UTC";
  const startOfDay = (calendarDay: string) =>
    computeNextDayStart(addDays(calendarDay, -1), timeZone).startsAt;
  const freeTrialTimes = match(computeFreeTrial(facts))
    .with({ type: "available" }, ({ lastDay }) => [
      startOfDay(addDays(lastDay, -2)),
      startOfDay(lastDay),
      startOfDay(addDays(lastDay, 1)),
    ])
    .with({ type: "used_by_earlier_account" }, () => [])
    .exhaustive();
  const times = [
    ...freeTrialTimes,
    computeSubscriptionEnd(computeSubscription(facts.transactions)),
  ];
  return {
    nextAt: findEarliest(times.filter((time) => time !== undefined && time > now)),
    isDue: times.some(
      (time) =>
        time !== undefined &&
        time.getTime() <= now.getTime() &&
        now.getTime() - time.getTime() < dueWindowMs,
    ),
  };
};

const dueWindowMs = 24 * 60 * 60 * 1000;
