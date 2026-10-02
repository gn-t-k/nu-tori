import { setTag } from "@sentry/cloudflare";
import { createMiddleware } from "hono/factory";
import { routePath } from "hono/route";

// 要求 ID は Cloudflare の Ray ID にし、Workers Logs と Sentry の報告を同じ ID で辿れるようにする。
// 失敗した段は、例外の stage の欄に持たせる（Durable Object の RPC を越えても独自の欄は届く）。
// ビルド番号は、古いビルドを締め出したとき（426）だけ足す
export const observeRequest = createMiddleware<{
  Bindings: Env;
  Variables: { accountId?: string; unsupportedAppBuild?: number };
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
    appBuild: c.get("unsupportedAppBuild"),
    error: c.error?.name,
    failedStage: c.error !== undefined && "stage" in c.error ? c.error.stage : undefined,
    durationMs: Date.now() - startedAt,
  });
});
