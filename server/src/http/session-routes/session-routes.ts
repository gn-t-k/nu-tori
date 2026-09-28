import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { APIError } from "better-auth/api";
import { createAppleRefreshTokenStore } from "../../auth/create-apple-refresh-token-store";
import { createAuthentication } from "../../auth/create-authentication";
import { exchangeAppleAuthorizationCode } from "../../auth/exchange-apple-authorization-code";

export const sessionRoutes = new OpenAPIHono<{ Bindings: Env }>().openapi(
  createRoute({
    method: "post",
    path: "/v1/sessions",
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
    const signedIn = await createAuthentication(c.env, c.req.url)
      .api.signInSocial({ body: { provider: "apple", idToken: { token: idToken, nonce } } })
      .catch((error: unknown) => {
        if (error instanceof APIError && error.status === "UNAUTHORIZED") {
          return undefined;
        }
        throw error;
      });
    if (signedIn === undefined || !("token" in signedIn)) {
      return c.body(null, 401);
    }
    const exchange = await exchangeAppleAuthorizationCode(c.env, authorizationCode);
    switch (exchange.kind) {
      case "rejected":
        return c.body(null, 401);
      case "exchanged":
        await createAppleRefreshTokenStore(c.env.DB, c.env.APPLE_REFRESH_TOKEN_KEYS).save(
          signedIn.user.id,
          exchange.refreshToken,
        );
        return c.json({ sessionToken: signedIn.token }, 201);
    }
  },
);
