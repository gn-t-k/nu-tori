import { env } from "cloudflare:workers";
import { z } from "zod";
import { signInWithApple } from "./sign-in-with-apple";

export const signInTestAccount = async (
  appleUserId: string,
  options: { timeZone?: string } = {},
): Promise<{ accountId: string; sessionToken: string }> => {
  const response = await signInWithApple(appleUserId, options);
  const { sessionToken } = z.object({ sessionToken: z.string() }).parse(await response.json());
  const account = await env.DB.prepare(
    `SELECT "userId" FROM account WHERE "providerId" = 'apple' AND "accountId" = ?`,
  )
    .bind(appleUserId)
    .first<{ userId: string }>();
  if (account === null) {
    throw new Error("サインインしたアカウントが無い");
  }
  return { accountId: account.userId, sessionToken };
};
