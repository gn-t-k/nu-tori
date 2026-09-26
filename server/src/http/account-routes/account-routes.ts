import { createRoute, OpenAPIHono } from "@hono/zod-openapi";
import { createAuthentication } from "../../auth/create-authentication";
import { deleteAccount } from "../../domain/delete-account";
import { authenticateAccount } from "../authenticate-account";
import { createAccountDeletionSteps } from "../create-account-deletion-steps";

export const accountRoutes = new OpenAPIHono<{ Bindings: Env }>().openapi(
  createRoute({
    method: "delete",
    path: "/v1/account",
    summary: "アカウントと記録をすべて消す",
    security: [{ session: [] }],
    middleware: [authenticateAccount] as const,
    responses: {
      204: { description: "消した" },
      401: { description: "セッションが無いか、切れている" },
      429: { description: "回数の歯止めにかかった" },
    },
  }),
  async (c) => {
    await deleteAccount(
      c.var.accountId,
      createAccountDeletionSteps(c.env, createAuthentication(c.env, c.req.url)),
    );
    return c.body(null, 204);
  },
);
