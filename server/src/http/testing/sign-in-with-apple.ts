import { env } from "cloudflare:workers";
import { signAppleIdToken } from "../../auth/testing";
import { app } from "../app";

// Apple の公開鍵と認可コードの交換は、呼ぶ側のテストで差し替えておく
export const signInWithApple = async (appleUserId: string): Promise<Response> => {
  const nonce = crypto.randomUUID();
  return app.request(
    "/v1/sessions",
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        idToken: await signAppleIdToken({ appleUserId, nonce }),
        nonce,
        authorizationCode: "authorization-code",
      }),
    },
    env,
  );
};
