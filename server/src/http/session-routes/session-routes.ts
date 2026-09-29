import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { APIError } from "better-auth/api";
import { match } from "ts-pattern";
import { createAppleRefreshTokenStore } from "../../auth/create-apple-refresh-token-store";
import { createAuthentication } from "../../auth/create-authentication";
import { exchangeAppleAuthorizationCode } from "../../auth/exchange-apple-authorization-code";

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
            }),
          },
        },
      },
    },
    responses: {
      201: {
        description: "サインインした。以後の要求では sessionToken を Bearer で送る",
        content: { "application/json": { schema: z.object({ sessionToken: z.string() }) } },
      },
      401: { description: "ID トークンか認可コードを受け付けなかった" },
    },
  }),
  async (c) => {
    const { idToken, nonce, authorizationCode } = c.req.valid("json");
    const signedIn = await R.pipe(
      signInWithAppleIdToken(createAuthentication(c.env, c.req.url), idToken, nonce),
      R.andThen((session) =>
        R.pipe(
          exchangeAppleAuthorizationCode(c.env, authorizationCode),
          R.map((refreshToken) => ({ session, refreshToken })),
        ),
      ),
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
    return c.json({ sessionToken: session.token }, 201);
  },
);

const signInWithAppleIdToken = (
  authentication: ReturnType<typeof createAuthentication>,
  idToken: string,
  nonce: string,
) =>
  authentication.api
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

class AppleIdTokenRejectedError extends ErrorFactory({
  name: "AppleIdTokenRejectedError",
  message: "Better Auth が Apple の ID トークンを受け付けなかった",
}) {}
