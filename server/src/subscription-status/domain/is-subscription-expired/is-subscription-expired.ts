import { match } from "ts-pattern";
import { computeSubscriptionEnd } from "../../../subscription/domain/compute-subscription-end";
import { isWithinFreeTrial } from "../../../subscription/domain/is-within-free-trial";
import type { SubscriptionStatus } from "../subscription-status";

// 推定を始める・返事を作る・週を見直すときの判定（#647 の「判定の決まり」の「使えるか」の裏）。
// テストユーザー、サブスクリプション中（今 < サブスクリプションの終わり）、無料体験中（数える日 ≤ 最後の日）のどれでもなければ切れ
export const isSubscriptionExpired = (
  status: SubscriptionStatus,
  { countedOn, now }: { countedOn: string; now: Date },
): boolean =>
  match(status)
    .with({ type: "test_user" }, () => false)
    .with({ type: "regular" }, ({ freeTrial, subscription }) => {
      const subscriptionEnd = computeSubscriptionEnd(subscription);
      const isSubscribed =
        subscriptionEnd !== undefined && now.getTime() < subscriptionEnd.getTime();
      return !isSubscribed && !isWithinFreeTrial(freeTrial, countedOn);
    })
    .exhaustive();
