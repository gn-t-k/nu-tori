import { env } from "cloudflare:workers";
import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/d1";
import { z } from "zod";
import { account as accountTable } from "../../auth/authentication-tables";
import { signInWithApple } from "./sign-in-with-apple";

export const signInTestAccount = async (
  appleUserId: string,
  options: { timeZone?: string } = {},
): Promise<{ accountId: string; sessionToken: string }> => {
  const response = await signInWithApple(appleUserId, options);
  const { sessionToken } = z.object({ sessionToken: z.string() }).parse(await response.json());
  const [account] = await drizzle(env.DB)
    .select({ userId: accountTable.userId })
    .from(accountTable)
    .where(and(eq(accountTable.providerId, "apple"), eq(accountTable.accountId, appleUserId)));
  if (account === undefined) {
    throw new Error("サインインしたアカウントが無い");
  }
  return { accountId: account.userId, sessionToken };
};
