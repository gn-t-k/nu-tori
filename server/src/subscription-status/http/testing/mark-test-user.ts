import { env } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/d1";
import { subscriptionD1Tables } from "../../../subscription/d1/subscription-d1-tables";

// 開発者が wrangler d1 execute で行を足すのと同じく、D1 にテストユーザーの旗を立てる
export const markTestUser = async (accountId: string): Promise<void> => {
  await drizzle(env.DB).insert(subscriptionD1Tables.testUsers).values({ accountId });
};
