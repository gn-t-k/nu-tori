import { env } from "cloudflare:workers";
import { SignJWT } from "jose";
import { appleSigningKey } from "./apple-signing-key";

export const signAppleIdToken = async ({
  appleUserId,
  nonce,
}: {
  appleUserId: string;
  nonce: string;
}): Promise<string> => {
  const { privateKey, publicJwk } = await appleSigningKey;
  return new SignJWT({ nonce, email: "user@privaterelay.appleid.com", email_verified: true })
    .setProtectedHeader({ alg: "RS256", kid: publicJwk.kid })
    .setIssuer("https://appleid.apple.com")
    .setAudience(env.APPLE_BUNDLE_ID)
    .setSubject(appleUserId)
    .setIssuedAt()
    .setExpirationTime("10m")
    .sign(privateKey);
};
