import { computeSubscriptionStatus } from "./compute-subscription-status";
import { readSubscriptionFacts } from "./read-subscription-facts";
import type { SubscriptionStatus } from "./subscription-status";
import type { SubscriptionStatusStore } from "./subscription-status-store";

// 推定・返事・週の見直しの判定に使う、今のサブスクリプションの状態。
// 最初のサインインは記録を書く前に済むので、記録を読み書きする流れで無いのは不具合
export const readSubscriptionStatus = (store: SubscriptionStatusStore): SubscriptionStatus =>
  computeSubscriptionStatus(readSubscriptionFacts(store));
