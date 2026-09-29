import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { createRemoteJWKSet, errors, jwtVerify } from "jose";
import { z } from "zod";

export const verifyAppleServerNotification = async (
  payload: string,
  bundleId: string,
): R.ResultAsync<AppleServerNotification, AppleServerNotificationUnverifiedError> => {
  const verified = await jwtVerify(payload, appleKeys, {
    issuer: "https://appleid.apple.com",
    audience: bundleId,
  }).then(
    (value) => R.succeed(value),
    (error: unknown) => {
      if (error instanceof errors.JOSEError) {
        return R.fail(new AppleServerNotificationUnverifiedError({ cause: error }));
      }
      throw error;
    },
  );
  if (R.isFailure(verified)) {
    return verified;
  }
  const { type, sub } = z
    .string()
    .transform((events) => JSON.parse(events))
    .pipe(z.object({ type: z.string(), sub: z.string() }))
    .parse(verified.value.payload["events"]);
  if (type === "consent-revoked" || type === "account-deleted") {
    return R.succeed({ type, appleUserId: sub });
  }
  return R.succeed({ type: "ignored" });
};

export class AppleServerNotificationUnverifiedError extends ErrorFactory({
  name: "AppleServerNotificationUnverifiedError",
  message: "Apple のサーバー間通知の署名を確かめられなかった",
}) {}

type AppleServerNotification =
  | { type: "consent-revoked" | "account-deleted"; appleUserId: string }
  | { type: "ignored" };

const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
