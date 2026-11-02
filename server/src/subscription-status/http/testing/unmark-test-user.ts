import { env } from "cloudflare:workers";
import { eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/d1";
import { subscriptionD1Tables } from "../../../subscription/d1/subscription-d1-tables";

// 開発者が wrangler d1 execute で行を消すのと同じく、D1 からテストユーザーの旗を外す
export const unmarkTestUser = async (accountId: string): Promise<void> => {
  const { testUsers } = subscriptionD1Tables;
  await drizzle(env.DB).delete(testUsers).where(eq(testUsers.accountId, accountId));
};
