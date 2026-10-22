import { eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/d1";
import { generateRecordId } from "../../domain/record-id";
import { subscriptionD1Tables } from "./subscription-d1-tables";

const { appAccountTokens } = subscriptionD1Tables;

// 購入者のトークン（StoreKit の appAccountToken）。アカウントごとに1つで、アカウントの ID とは別の UUID にする
export const createAppAccountTokenStore = (d1: D1Database) => {
  const db = drizzle(d1);
  const find = async (accountId: string): Promise<string | undefined> => {
    const row = await db
      .select({ appAccountToken: appAccountTokens.appAccountToken })
      .from(appAccountTokens)
      .where(eq(appAccountTokens.accountId, accountId))
      .get();
    return row?.appAccountToken;
  };
  return {
    // まだ無ければ出して書く。同じアカウントの要求が並んでも、先に書いたほうの値を返す
    issue: async (accountId: string): Promise<string> => {
      const existing = await find(accountId);
      if (existing !== undefined) {
        return existing;
      }
      await db
        .insert(appAccountTokens)
        .values({ accountId, appAccountToken: generateRecordId() })
        .onConflictDoNothing({ target: appAccountTokens.accountId });
      const issued = await find(accountId);
      if (issued === undefined) {
        throw new Error("書いた購入者のトークンが読めない");
      }
      return issued;
    },
    // 購入者のトークンの持ち主。退会したアカウントの行は消えているので、今あるアカウントだけが引ける
    findAccountId: async (appAccountToken: string): Promise<string | undefined> => {
      const row = await db
        .select({ accountId: appAccountTokens.accountId })
        .from(appAccountTokens)
        .where(eq(appAccountTokens.appAccountToken, appAccountToken))
        .get();
      return row?.accountId;
    },
  };
};
