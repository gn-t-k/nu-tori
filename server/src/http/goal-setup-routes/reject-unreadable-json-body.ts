import { captureException } from "@sentry/cloudflare";
import { createMiddleware } from "hono/factory";
import { GoalSetupRequestMalformedError } from "./goal-setup-request-malformed-error";

// JSON として読めない本文も、ほかの形の誤りと同じく 400 で断って Sentry に送る。
// 置かないと、検証の手前で Hono が自分の 400 を返し、Sentry に届かない。読んだ本文は Hono が持つので、検証が読み直さない
export const rejectUnreadableJsonBody = createMiddleware<{ Bindings: Env }>(async (c, next) => {
  const readable = await c.req.json().then(
    () => true,
    () => false,
  );
  if (!readable) {
    captureException(
      new GoalSetupRequestMalformedError({ issues: [{ path: "", code: "invalid_json" }] }),
    );
    return c.json({ code: "malformed_request" }, 400);
  }
  return next();
});
