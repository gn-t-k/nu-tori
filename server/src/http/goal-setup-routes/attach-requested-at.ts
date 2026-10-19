import { createMiddleware } from "hono/factory";
import { resolveRequestedAt } from "../e2e-session-routes/resolve-requested-at";

// 目標の設定の要求を受けた時刻を c.var.requestedAt に置く。確かめのジョブの差し替えは resolveRequestedAt が受け付ける
export const attachRequestedAt = createMiddleware<{
  Bindings: Env;
  Variables: { requestedAt: Date };
}>(async (c, next) => {
  c.set("requestedAt", await resolveRequestedAt(c.env, (name) => c.req.header(name)));
  return next();
});
