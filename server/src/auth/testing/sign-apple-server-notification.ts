import { env } from "cloudflare:workers";
import { SignJWT } from "jose";
import { appleSigningKey } from "./apple-signing-key";

// Apple は events を JSON の文字列にして送る
export const signAppleServerNotification = async ({
  appleUserId,
  type,
}: {
  appleUserId: string;
  type: string;
}): Promise<string> => {
  const { privateKey, publicJwk } = await appleSigningKey;
  return (
    new SignJWT({
      events: JSON.stringify({ type, sub: appleUserId, event_time: Date.now() }),
    })
      .setProtectedHeader({ alg: "RS256", kid: publicJwk.kid })
      .setIssuer("https://appleid.apple.com")
      .setAudience(env.APPLE_BUNDLE_ID)
      .setIssuedAt()
      // oxlint-disable-next-line nu-tori/no-random-uuid -- テストで作る Apple の JWT の ID で、DB にも API にも出さない
      .setJti(crypto.randomUUID())
      .sign(privateKey)
  );
};
