import { toAppStoreSubscriptionKey } from "../domain/app-store-subscription-key";
import type { AppStoreSubscriptionTransaction } from "../domain/read-app-store-subscription-transaction";
import { createAppAccountTokenStore } from "./create-app-account-token-store";
import { createAppStoreSubscriptionRouteStore } from "./create-app-store-subscription-route-store";

// App Store のサーバー通知を書くアカウントを D1 で決める（#647 の「App Store のサーバー通知を受ける」）。
// 元の取引の ID の案内を先に引き、無いときだけ取引の購入者のトークンで引いて案内を書く。
// どちらでも引けなければ undefined
export const routeAppStoreServerNotification = async (
  d1: D1Database,
  transaction: AppStoreSubscriptionTransaction,
): Promise<string | undefined> => {
  const routes = createAppStoreSubscriptionRouteStore(d1);
  const key = toAppStoreSubscriptionKey(transaction);
  const routedAccountId = await routes.findAccountId(key);
  if (routedAccountId !== undefined) {
    return routedAccountId;
  }
  if (transaction.appAccountToken === undefined) {
    return undefined;
  }
  const tokenAccountId = await createAppAccountTokenStore(d1).findAccountId(
    transaction.appAccountToken,
  );
  // 並んだ端末の知らせがほかのアカウントで先に書いていれば、そのアカウントに書く
  return tokenAccountId === undefined ? undefined : routes.link(tokenAccountId, key);
};
