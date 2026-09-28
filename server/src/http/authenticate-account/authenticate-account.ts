import { setUser } from "@sentry/cloudflare";
import { createMiddleware } from "hono/factory";
import { createAuthentication } from "../../auth/create-authentication";

export const authenticateAccount = createMiddleware<{
  Bindings: Env;
  Variables: { accountId: string };
}>(async (c, next) => {
  const session = await createAuthentication(c.env, c.req.url).api.getSession({
    headers: c.req.raw.headers,
  });
  if (session === null) {
    return c.body(null, 401);
  }
  const { success } = await c.env.ACCOUNT_RATE_LIMITER.limit({ key: session.user.id });
  if (!success) {
    return c.body(null, 429);
  }
  c.set("accountId", session.user.id);
  setUser({ id: session.user.id });
  return next();
});
