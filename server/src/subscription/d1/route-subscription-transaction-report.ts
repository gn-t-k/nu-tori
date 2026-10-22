import { toAppStoreSubscriptionKey } from "../domain/app-store-subscription-key";
import type { AppStoreSubscriptionTransaction } from "../domain/read-app-store-subscription-transaction";
import { createAppAccountTokenStore } from "./create-app-account-token-store";
import { createAppStoreSubscriptionRouteStore } from "./create-app-store-subscription-route-store";

// 端末から知らされた取引を、このアカウントに結びつけてよいかを D1 で決める（#647 の「取引を知らせる」）。
// ほかのアカウントの案内がある、または取引の購入者のトークンがほかの今あるアカウントのものなら、何も書かずに断る。
// 案内が無ければこのアカウントで書く
export const routeSubscriptionTransactionReport = async (
  d1: D1Database,
  accountId: string,
  transaction: AppStoreSubscriptionTransaction,
): Promise<"linked" | "owned_by_other_account"> => {
  const routes = createAppStoreSubscriptionRouteStore(d1);
  const key = toAppStoreSubscriptionKey(transaction);
  const routedAccountId = await routes.findAccountId(key);
  if (routedAccountId !== undefined && routedAccountId !== accountId) {
    return "owned_by_other_account";
  }
  if (transaction.appAccountToken !== undefined) {
    const tokenAccountId = await createAppAccountTokenStore(d1).findAccountId(
      transaction.appAccountToken,
    );
    if (tokenAccountId !== undefined && tokenAccountId !== accountId) {
      return "owned_by_other_account";
    }
  }
  if (routedAccountId === undefined && (await routes.link(accountId, key)) !== accountId) {
    return "owned_by_other_account";
  }
  return "linked";
};
