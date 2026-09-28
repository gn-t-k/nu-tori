import { createRemoteJWKSet, errors, jwtVerify } from "jose";
import { z } from "zod";

export const verifyAppleServerNotification = async (
  payload: string,
  bundleId: string,
): Promise<AppleServerNotification> => {
  const verified = await jwtVerify(payload, appleKeys, {
    issuer: "https://appleid.apple.com",
    audience: bundleId,
  }).catch((error: unknown) => {
    if (error instanceof errors.JOSEError) {
      return undefined;
    }
    throw error;
  });
  if (verified === undefined) {
    return { type: "unverified" };
  }
  const { type, sub } = z
    .string()
    .transform((events) => JSON.parse(events))
    .pipe(z.object({ type: z.string(), sub: z.string() }))
    .parse(verified.payload["events"]);
  if (type === "consent-revoked" || type === "account-deleted") {
    return { type, appleUserId: sub };
  }
  return { type: "ignored" };
};

type AppleServerNotification =
  | { type: "consent-revoked" | "account-deleted"; appleUserId: string }
  | { type: "ignored" }
  | { type: "unverified" };

const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
