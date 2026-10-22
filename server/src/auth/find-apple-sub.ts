import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/d1";
import { authenticationTables } from "./authentication-tables";

const { account } = authenticationTables;

// アカウントの Apple の sub（Better Auth の account の accountId）。
// 確かめのジョブのサインインの口で作ったアカウントは Apple を通さないので無い
export const findAppleSub = async (
  d1: D1Database,
  accountId: string,
): Promise<string | undefined> => {
  const [row] = await drizzle(d1)
    .select({ appleSub: account.accountId })
    .from(account)
    .where(and(eq(account.userId, accountId), eq(account.providerId, "apple")))
    .limit(1);
  return row?.appleSub;
};
