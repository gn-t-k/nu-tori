import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { createAuthentication } from "../../auth/create-authentication";
import { verifyAppleServerNotification } from "../../auth/verify-apple-server-notification";
import { deleteAccount } from "../../domain/delete-account";
import { createAccountDeletionSteps } from "../create-account-deletion-steps";

// Apple が呼ぶ口なので、アプリが読む OpenAPI の文書には出さない
export const appleServerNotificationRoutes = new OpenAPIHono<{ Bindings: Env }>().openapi(
  createRoute({
    method: "post",
    path: "/v1/apple-server-notifications",
    hide: true,
    request: {
      body: {
        required: true,
        content: { "application/json": { schema: z.object({ payload: z.string() }) } },
      },
    },
    responses: {
      200: { description: "受け取った" },
      400: { description: "署名を確かめられなかった" },
    },
  }),
  async (c) => {
    const notification = await verifyAppleServerNotification(
      c.req.valid("json").payload,
      c.env.APPLE_BUNDLE_ID,
    );
    switch (notification.type) {
      case "unverified":
        return c.body(null, 400);
      case "ignored":
        return c.body(null, 200);
      case "consent-revoked": {
        const authentication = createAuthentication(c.env, c.req.url);
        const accountId = await findAccountId(authentication, notification.appleUserId);
        if (accountId !== undefined) {
          // 記録は残し、同じ Apple ID でサインインし直せば戻れるようにする
          const { internalAdapter } = await authentication.$context;
          await internalAdapter.deleteUserSessions(accountId);
        }
        return c.body(null, 200);
      }
      case "account-deleted": {
        const authentication = createAuthentication(c.env, c.req.url);
        const accountId = await findAccountId(authentication, notification.appleUserId);
        if (accountId !== undefined) {
          await deleteAccount(accountId, createAccountDeletionSteps(c.env, authentication));
        }
        return c.body(null, 200);
      }
    }
  },
);

const findAccountId = async (
  authentication: ReturnType<typeof createAuthentication>,
  appleUserId: string,
): Promise<string | undefined> => {
  const { internalAdapter } = await authentication.$context;
  const owner = await internalAdapter.findAccountOwnerByKey({
    providerId: "apple",
    accountId: appleUserId,
  });
  return owner?.kind === "owned" ? owner.user.id : undefined;
};
