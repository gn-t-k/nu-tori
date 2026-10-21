import type { FreeTrial } from "../../subscription/domain/compute-free-trial";
import type { Subscription } from "../../subscription/domain/compute-subscription";

// サブスクリプションの状態。表に持たず、事実から計算する。記録の ID は最初のサインインの ID で、1アカウントに1件。
// テストユーザーは、端末が無料体験のカードも日数も出さないので、ほかの値を持たない
export type SubscriptionStatus =
  | { type: "test_user" }
  | { type: "regular"; freeTrial: FreeTrial; subscription: Subscription };
