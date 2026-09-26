import { importPKCS8, SignJWT } from "jose";
import type { AppleCredentials } from "./apple-credentials";

export const createAppleClientSecret = async (apple: AppleCredentials): Promise<string> => {
  const privateKey = await importPKCS8(apple.APPLE_PRIVATE_KEY, "ES256");
  return new SignJWT()
    .setProtectedHeader({ alg: "ES256", kid: apple.APPLE_KEY_ID })
    .setIssuer(apple.APPLE_TEAM_ID)
    .setSubject(apple.APPLE_BUNDLE_ID)
    .setAudience("https://appleid.apple.com")
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(privateKey);
};
