import { createServerOnlyKind } from "../../domain/sync-ledger/create-server-only-kind";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import { computeSubscriptionStatus } from "./compute-subscription-status";
import type { SubscriptionStatus } from "./subscription-status";
import type { SubscriptionStatusStore } from "./subscription-status-store";

// サブスクリプションの状態の種類。サーバーだけが書き、記録の ID は最初のサインインの ID で、消えない
export const createSubscriptionStatusKind = (
  store: SubscriptionStatusStore,
): RecordKind<"subscription_status", never, SubscriptionStatus> =>
  createServerOnlyKind({
    name: "subscription_status",
    whenGone: "never",
    find: (recordId) => {
      const facts = store.findFacts();
      return facts?.firstSignInId === recordId ? computeSubscriptionStatus(facts) : undefined;
    },
  });
