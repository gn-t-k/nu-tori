import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { z } from "zod";
import type { AppleCredentials } from "../apple-credentials";
import { createAppleClientSecret } from "../create-apple-client-secret";

export const exchangeAppleAuthorizationCode = async (
  apple: AppleCredentials,
  authorizationCode: string,
): R.ResultAsync<string, AppleAuthorizationCodeRejectedError> => {
  const response = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    body: new URLSearchParams({
      client_id: apple.APPLE_BUNDLE_ID,
      client_secret: await createAppleClientSecret(apple),
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  });
  if (response.ok) {
    const { refresh_token } = z.object({ refresh_token: z.string() }).parse(await response.json());
    return R.succeed(refresh_token);
  }
  const failure = z
    .object({ error: z.string() })
    .safeParse(await response.json().catch(() => undefined));
  if (failure.success && failure.data.error === "invalid_grant") {
    return R.fail(new AppleAuthorizationCodeRejectedError());
  }
  throw new Error(`Apple の認可コードの交換に失敗した: ${response.status}`);
};

export class AppleAuthorizationCodeRejectedError extends ErrorFactory({
  name: "AppleAuthorizationCodeRejectedError",
  message: "Apple が認可コードを受け付けなかった",
}) {}
