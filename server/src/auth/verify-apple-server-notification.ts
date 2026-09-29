import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { createRemoteJWKSet, errors, jwtVerify } from "jose";
import type { JWTPayload } from "jose";
import { z } from "zod";

export const verifyAppleServerNotification = (
  payload: string,
  bundleId: string,
): R.ResultAsync<AppleServerNotification, AppleServerNotificationUnverifiedError> => {
  return R.pipe(
    jwtVerify(payload, appleKeys, {
      issuer: "https://appleid.apple.com",
      audience: bundleId,
    }).then(
      (verified) => R.succeed(verified),
      (error: unknown) => {
        if (error instanceof errors.JOSEError) {
          return R.fail(new AppleServerNotificationUnverifiedError({ cause: error }));
        }
        throw error;
      },
    ),
    R.map((verified) => readAppleServerNotification(verified.payload)),
  );
};

export class AppleServerNotificationUnverifiedError extends ErrorFactory({
  name: "AppleServerNotificationUnverifiedError",
  message: "Apple のサーバー間通知の署名を確かめられなかった",
}) {}

type AppleServerNotification =
  | { type: "consent-revoked" | "account-deleted"; appleUserId: string }
  | { type: "ignored" };

const readAppleServerNotification = (payload: JWTPayload): AppleServerNotification => {
  const { type, sub } = z
    .string()
    .transform((events) => JSON.parse(events))
    .pipe(z.object({ type: z.string(), sub: z.string() }))
    .parse(payload["events"]);
  if (type === "consent-revoked" || type === "account-deleted") {
    return { type, appleUserId: sub };
  }
  return { type: "ignored" };
};

const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
