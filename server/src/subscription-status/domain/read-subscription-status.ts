import { computeSubscriptionStatus } from "./compute-subscription-status";
import type { SubscriptionStatus } from "./subscription-status";
import type { SubscriptionStatusFacts, SubscriptionStatusStore } from "./subscription-status-store";

// 推定・返事・週の見直しの判定に使う、今のサブスクリプションの状態。
// 最初のサインインは記録を書く前に済むので、記録を読み書きする流れで無いのは不具合
export const readSubscriptionStatus = (store: SubscriptionStatusStore): SubscriptionStatus =>
  computeSubscriptionStatus(readSubscriptionFacts(store));

// 状態の元の事実。最初のサインインが無ければ投げる
export const readSubscriptionFacts = (store: SubscriptionStatusStore): SubscriptionStatusFacts => {
  const facts = store.findFacts();
  if (facts === undefined) {
    throw new Error("最初のサインインが無いアカウントで、サブスクリプションの状態を読もうとした");
  }
  return facts;
};
