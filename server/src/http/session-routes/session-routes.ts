import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { APIError } from "better-auth/api";
import { decodeJwt } from "jose";
import { match } from "ts-pattern";
import { createAppleRefreshTokenStore } from "../../auth/create-apple-refresh-token-store";
import { createAuthentication } from "../../auth/create-authentication";
import { exchangeAppleAuthorizationCode } from "../../auth/exchange-apple-authorization-code";
import { findAppleSub } from "../../auth/find-apple-sub";
import { computeSha256Hex } from "../../domain/compute-sha256-hex";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { createFreeTrialUsageStore } from "../../subscription/d1/create-free-trial-usage-store";

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
      isFreeTrialUsedByEarlierAccount: await isFreeTrialUsedByEarlierAccount(
        c.env,
        session.user.id,
      ),
    });
    return c.json({ sessionToken: session.token, accountId: session.user.id }, 201);
  },
);

// 最初のサインインかどうかは Durable Object が決めるので、サインインのたびに引く
const isFreeTrialUsedByEarlierAccount = async (env: Env, accountId: string): Promise<boolean> => {
  const appleSub = await findAppleSub(env.DB, accountId);
  if (appleSub === undefined) {
    throw new Error("Apple でサインインしたアカウントに Apple の sub が無い");
  }
  return createFreeTrialUsageStore(env.DB, env.APPLE_SUB_HASH_KEYS).isUsed(appleSub);
};

const signInWithAppleIdToken = (
  authentication: ReturnType<typeof createAuthentication>,
  idToken: string,
  nonce: string,
) =>
  Promise.all([computeSha256Hex(nonce), readUnverifiedIdTokenNonce(idToken)]).then(
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
