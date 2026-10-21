import { match } from "ts-pattern";
import type { Subscription } from "../compute-subscription";

// サブスクリプション中でいられる最後の時刻。取り消されていない取引の期限と、請求の猶予の終わりの遅いほう。
// 猶予は期限より遅いときだけ granted なので、あればその終わりになる。今がこれより前ならサブスクリプション中
export const computeSubscriptionEnd = (subscription: Subscription): Date | undefined =>
  match(subscription)
    .with({ type: "none" }, () => undefined)
    .with({ type: "subscribed" }, ({ periodEndsAt, billingGrace }) =>
      match(billingGrace)
        .with({ type: "none" }, () => periodEndsAt)
        .with({ type: "granted" }, ({ endsAt }) => endsAt)
        .exhaustive(),
    )
    .exhaustive();
