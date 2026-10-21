import { eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/d1";
import { isCalendarDay } from "../../domain/is-calendar-day";
import { subscriptionD1Tables } from "./subscription-d1-tables";

// サブスクリプションの状態の元のうち、Durable Object の外にあるもの。
// テストユーザーの旗の変化は Durable Object が知らないので、要求とアラームのたびに D1 を引く
export const readSubscriptionAccount = async (
  env: Pick<Env, "DB" | "BILLING_STARTED_ON">,
  accountId: string,
): Promise<{ isTestUser: boolean; billingStartedOn: string }> => {
  if (!isCalendarDay(env.BILLING_STARTED_ON)) {
    throw new Error("課金を入れた日（BILLING_STARTED_ON）が YYYY-MM-DD の日付でない");
  }
  const { testUsers } = subscriptionD1Tables;
  const testUser = await drizzle(env.DB)
    .select({ accountId: testUsers.accountId })
    .from(testUsers)
    .where(eq(testUsers.accountId, accountId))
    .get();
  return { isTestUser: testUser !== undefined, billingStartedOn: env.BILLING_STARTED_ON };
};
