import { match } from "ts-pattern";
import { computeSubscriptionEnd } from "../../../subscription/domain/compute-subscription-end";
import { isWithinFreeTrial } from "../../../subscription/domain/is-within-free-trial";
import type { SubscriptionStatus } from "../subscription-status";

// 推定を始める・返事を作る・週を見直すときの判定（#647 の「判定の決まり」の「使えるか」の裏）。
// テストユーザー、サブスクリプション中（at < サブスクリプションの終わり）、無料体験中（数える日 ≤ 最後の日）のどれでもなければ切れ。
// at は、推定と返事では今、週の見直しでは見直す月曜の始まり
export const isSubscriptionExpired = (
  status: SubscriptionStatus,
  { countedOn, at }: { countedOn: string; at: Date },
): boolean =>
  match(status)
    .with({ type: "test_user" }, () => false)
    .with({ type: "regular" }, ({ freeTrial, subscription }) => {
      const subscriptionEnd = computeSubscriptionEnd(subscription);
      const isSubscribed =
        subscriptionEnd !== undefined && at.getTime() < subscriptionEnd.getTime();
      return !isSubscribed && !isWithinFreeTrial(freeTrial, countedOn);
    })
    .exhaustive();
