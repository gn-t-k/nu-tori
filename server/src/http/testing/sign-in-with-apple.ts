import { env } from "cloudflare:workers";
import { signAppleIdToken } from "../../auth/testing";
import { app } from "../app";
import { sha256Hex } from "./sha256-hex";

// Apple の公開鍵と認可コードの交換は、呼ぶ側のテストで差し替えておく
export const signInWithApple = async (
  appleUserId: string,
  options: { timeZone?: string } = {},
): Promise<Response> => {
  // oxlint-disable-next-line nu-tori/no-random-uuid -- テストで作る Apple のサインインの nonce で、ID として比べない
  const nonce = crypto.randomUUID();
  return app.request(
    "/v1/sessions",
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        idToken: await signAppleIdToken({ appleUserId, nonce: await sha256Hex(nonce) }),
        nonce,
        authorizationCode: "authorization-code",
        ...options,
      }),
    },
    env,
  );
};
