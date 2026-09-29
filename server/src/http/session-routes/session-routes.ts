import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { APIError } from "better-auth/api";
import { decodeJwt } from "jose";
import { match } from "ts-pattern";
import { createAppleRefreshTokenStore } from "../../auth/create-apple-refresh-token-store";
import { createAuthentication } from "../../auth/create-authentication";
import { exchangeAppleAuthorizationCode } from "../../auth/exchange-apple-authorization-code";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";

export const sessionRoutes = new OpenAPIHono<{ Bindings: Env }>().openapi(
  createRoute({
    method: "post",
    path: "/v1/sessions",
    operationId: "createSession",
    summary: "Sign in with Apple でサインインし、セッションを始める",
    request: {
      body: {
        required: true,
        content: {
          "application/json": {
            schema: z.object({
              idToken: z.string(),
              nonce: z.string().min(1),
              authorizationCode: z.string(),
              timeZone: z.string().optional().openapi({
                description:
                  "端末の IANA のタイムゾーン名。最初のサインインで、使い始めた日をこの土地の日付にする",
                example: "Asia/Tokyo",
              }),
            }),
          },
        },
      },
    },
    responses: {
      201: {
        description: "サインインした。以後の要求では sessionToken を Bearer で送る",
        content: {
          "application/json": {
            schema: z.object({
              sessionToken: z.string(),
              accountId: z.string().openapi({ description: "nu-tori のアカウント ID" }),
            }),
          },
        },
      },
      401: { description: "ID トークンか認可コードを受け付けなかった" },
    },
  }),
  async (c) => {
    const { idToken, nonce, authorizationCode, timeZone } = c.req.valid("json");
    const signedIn = await R.pipe(
      R.do(),
      R.bind("session", () =>
        signInWithAppleIdToken(createAuthentication(c.env, c.req.url), idToken, nonce),
      ),
      R.bind("refreshToken", () => exchangeAppleAuthorizationCode(c.env, authorizationCode)),
    );
    if (R.isFailure(signedIn)) {
      return match(signedIn.error)
        .with(
          { name: "AppleIdTokenRejectedError" },
          { name: "AppleAuthorizationCodeRejectedError" },
          () => c.body(null, 401),
        )
        .exhaustive();
    }
    const { session, refreshToken } = signedIn.value;
    await createAppleRefreshTokenStore(c.env.DB, c.env.APPLE_REFRESH_TOKEN_KEYS).save(
      session.user.id,
      refreshToken,
    );
    await getAccountDurableObject(c.env, session.user.id).recordFirstSignIn(session.user.id, {
      signedInAt: new Date(),
      timeZone,
    });
    return c.json({ sessionToken: session.token, accountId: session.user.id }, 201);
  },
);

const signInWithAppleIdToken = (
  authentication: ReturnType<typeof createAuthentication>,
  idToken: string,
  nonce: string,
) =>
  Promise.all([sha256Hex(nonce), readUnverifiedIdTokenNonce(idToken)]).then(
    ([hashed, tokenNonce]) => {
      if (tokenNonce !== hashed) {
        return R.fail(new AppleIdTokenRejectedError());
      }
      return authentication.api
        .signInSocial({ body: { provider: "apple", idToken: { token: idToken, nonce } } })
        .then(
          (signedIn) =>
            "token" in signedIn ? R.succeed(signedIn) : R.fail(new AppleIdTokenRejectedError()),
          (error: unknown) => {
            if (error instanceof APIError && error.status === "UNAUTHORIZED") {
              return R.fail(new AppleIdTokenRejectedError({ cause: error }));
            }
            throw error;
          },
        );
    },
  );

const sha256Hex = async (value: string): Promise<string> => {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
};

// 署名は見ない。署名とハッシュでの一致は、このあとの signInSocial が確かめる
const readUnverifiedIdTokenNonce = (idToken: string): Promise<string | undefined> =>
  Promise.resolve()
    .then(() => decodeJwt(idToken))
    .then(
      (payload) => {
        const nonce = payload["nonce"];
        return typeof nonce === "string" ? nonce : undefined;
      },
      () => undefined,
    );

class AppleIdTokenRejectedError extends ErrorFactory({
  name: "AppleIdTokenRejectedError",
  message: "Apple の ID トークンを受け付けなかった",
}) {}
