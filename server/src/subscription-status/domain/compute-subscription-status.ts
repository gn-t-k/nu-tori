import { computeFreeTrial } from "../../subscription/domain/compute-free-trial";
import { computeSubscription } from "../../subscription/domain/compute-subscription";
import type { SubscriptionStatus } from "./subscription-status";
import type { SubscriptionStatusFacts } from "./subscription-status-store";

export const computeSubscriptionStatus = (facts: SubscriptionStatusFacts): SubscriptionStatus =>
  facts.isTestUser
    ? { type: "test_user" }
    : {
        type: "regular",
        freeTrial: computeFreeTrial(facts),
        subscription: computeSubscription(facts.transactions),
      };
