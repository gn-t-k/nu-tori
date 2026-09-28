import type { AppleCredentials } from "../apple-credentials";
import { createAppleClientSecret } from "../create-apple-client-secret";
import { RevokeAppleRefreshTokenError } from "./revoke-apple-refresh-token-error";

// Apple は、取り消したときも、すでに無効だったときも 200 を返す
export const revokeAppleRefreshToken = async (
  apple: AppleCredentials,
  refreshToken: string,
): Promise<void> => {
  const response = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    body: new URLSearchParams({
      client_id: apple.APPLE_BUNDLE_ID,
      client_secret: await createAppleClientSecret(apple),
      token: refreshToken,
      token_type_hint: "refresh_token",
    }),
  });
  if (!response.ok) {
    throw new RevokeAppleRefreshTokenError(response.status);
  }
};
