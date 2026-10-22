import type { AppStoreSubscriptionTransaction } from "./read-app-store-subscription-transaction";
import type { AppStoreSubscriptionEnvironment } from "./subscription-transaction-fact";

// App Store のサブスクリプションを見分ける組。DO のサブスクリプションと D1 の案内は、この組で引く
export type AppStoreSubscriptionKey = {
  environment: AppStoreSubscriptionEnvironment;
  appStoreOriginalTransactionId: string;
};

export const toAppStoreSubscriptionKey = ({
  environment,
  appStoreOriginalTransactionId,
}: AppStoreSubscriptionTransaction): AppStoreSubscriptionKey => ({
  environment,
  appStoreOriginalTransactionId,
});
