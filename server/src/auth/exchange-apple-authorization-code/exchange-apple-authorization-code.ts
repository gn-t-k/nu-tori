import { z } from "zod";
import type { AppleCredentials } from "../apple-credentials";
import { createAppleClientSecret } from "../create-apple-client-secret";

export const exchangeAppleAuthorizationCode = async (
  apple: AppleCredentials,
  authorizationCode: string,
): Promise<AppleAuthorizationCodeExchange> => {
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
    return { kind: "exchanged", refreshToken: refresh_token };
  }
  const failure = z
    .object({ error: z.string() })
    .safeParse(await response.json().catch(() => undefined));
  if (failure.success && failure.data.error === "invalid_grant") {
    return { kind: "rejected" };
  }
  throw new Error(`Apple の認可コードの交換に失敗した: ${response.status}`);
};

type AppleAuthorizationCodeExchange =
  | { kind: "exchanged"; refreshToken: string }
  | { kind: "rejected" };
