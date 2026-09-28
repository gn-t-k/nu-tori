import { setTag } from "@sentry/cloudflare";
import { createMiddleware } from "hono/factory";
import { routePath } from "hono/route";

// 要求 ID は Cloudflare の Ray ID にし、Workers Logs と Sentry の報告を同じ ID で辿れるようにする
export const observeRequest = createMiddleware<{
  Bindings: Env;
  Variables: { accountId?: string };
}>(async (c, next) => {
  const requestId = c.req.header("cf-ray") ?? crypto.randomUUID();
  setTag("requestId", requestId);
  const startedAt = Date.now();
  await next();
  console.log({
    requestId,
    accountId: c.get("accountId"),
    route: `${c.req.method} ${routePath(c, -1)}`,
    status: c.res.status,
    durationMs: Date.now() - startedAt,
  });
});
