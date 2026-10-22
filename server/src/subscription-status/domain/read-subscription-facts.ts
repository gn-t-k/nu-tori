import type { SubscriptionStatusFacts, SubscriptionStatusStore } from "./subscription-status-store";

// サブスクリプションの状態の元の事実。最初のサインインは記録を書く前に済むので、無ければ不具合として投げる
export const readSubscriptionFacts = (store: SubscriptionStatusStore): SubscriptionStatusFacts => {
  const facts = store.findFacts();
  if (facts === undefined) {
    throw new Error("最初のサインインが無いアカウントで、サブスクリプションの状態を読もうとした");
  }
  return facts;
};
