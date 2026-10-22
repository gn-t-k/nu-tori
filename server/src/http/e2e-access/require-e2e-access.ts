import { createMiddleware } from "hono/factory";
import { match } from "ts-pattern";
import { checkE2eAccess } from "./check-e2e-access";
import { e2eRequestHeaders } from "./e2e-request-headers";

// 確かめのジョブのための口の入口。開かないときは口が無いのと同じ 404 に、秘密の値が違えば 401 にする
export const requireE2eAccess = createMiddleware<{ Bindings: Env }>(async (c, next) =>
  match(await checkE2eAccess(c.env, c.req.header(e2eRequestHeaders.signInSecret)))
    .with("closed", () => c.notFound())
    .with("unauthorized", () => c.body(null, 401))
    .with("allowed", () => next())
    .exhaustive(),
);
