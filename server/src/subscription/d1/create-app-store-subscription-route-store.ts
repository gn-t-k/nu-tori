import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/d1";
import { generateRecordId } from "../../domain/record-id";
import type { AppStoreSubscriptionKey } from "../domain/subscription-transaction-store";
import { subscriptionD1Tables } from "./subscription-d1-tables";

const { appStoreSubscriptionRoutes } = subscriptionD1Tables;

// App Store のサブスクリプションの案内。環境と元の取引の ID の組で、最初に結びついたアカウントのもの。
// 退会するとアカウントの行と一緒に消える（ON DELETE CASCADE）ので、あとで別のアカウントが結びつける
export const createAppStoreSubscriptionRouteStore = (d1: D1Database) => {
  const db = drizzle(d1);
  const findAccountId = async ({
    environment,
    appStoreOriginalTransactionId,
  }: AppStoreSubscriptionKey): Promise<string | undefined> => {
    const row = await db
      .select({ accountId: appStoreSubscriptionRoutes.accountId })
      .from(appStoreSubscriptionRoutes)
      .where(
        and(
          eq(appStoreSubscriptionRoutes.environment, environment),
          eq(
            appStoreSubscriptionRoutes.appStoreOriginalTransactionId,
            appStoreOriginalTransactionId,
          ),
        ),
      )
      .get();
    return row?.accountId;
  };
  return {
    findAccountId,
    // 案内が無ければこのアカウントで書き、案内の持ち主を返す。並んだ要求がほかのアカウントで先に書いていれば、そのアカウントを返す
    link: async (accountId: string, key: AppStoreSubscriptionKey): Promise<string> => {
      await db
        .insert(appStoreSubscriptionRoutes)
        .values({ id: generateRecordId(), accountId, ...key })
        .onConflictDoNothing({
          target: [
            appStoreSubscriptionRoutes.environment,
            appStoreSubscriptionRoutes.appStoreOriginalTransactionId,
          ],
        });
      const owner = await findAccountId(key);
      if (owner === undefined) {
        throw new Error("書いた案内が読めない");
      }
      return owner;
    },
  };
};
