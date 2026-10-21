import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { R } from "@praha/byethrow";
import { readAppStoreRootCertificate } from "../../app-store/app-store-root-certificate";
import { verifyAppStoreServerNotification } from "../../app-store/verify-app-store-server-notification";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { routeAppStoreServerNotification } from "../../subscription/d1/route-app-store-server-notification";
import { readAppStoreSubscriptionTransaction } from "../../subscription/domain/read-app-store-subscription-transaction";
import type { AppStoreNotificationLogVariables } from "../observe-request";

// App Store のサーバー通知（App Store Server Notifications V2）の受け口（#647 の「App Store のサーバー通知を受ける」）。
// Sign in with Apple の /v1/apple-server-notifications とは別の口。
// Apple が呼ぶ口なので、アプリが読む OpenAPI の文書には出さない（アプリのクライアントに入れない）
export const appStoreServerNotificationRoutes = new OpenAPIHono<{
  Bindings: Env;
  Variables: { accountId?: string } & AppStoreNotificationLogVariables;
}>().openapi(
  createRoute({
    method: "post",
    path: "/v1/app-store-server-notifications",
    hide: true,
    request: {
      body: {
        required: true,
        content: { "application/json": { schema: z.object({ signedPayload: z.string() }) } },
      },
    },
    responses: {
      200: { description: "受け取った。重なり、案内できない通知も含む" },
      400: {
        description:
          "署名を確かめられない、ほかのアプリの通知、環境が Production・Sandbox でない、知らない商品",
      },
      500: { description: "取り消しの戻しが、戻す取り消しより先に届いた。Apple の送り直しを待つ" },
    },
  }),
  async (c) => {
    const verified = await verifyAppStoreServerNotification(
      c.req.valid("json").signedPayload,
      readAppStoreRootCertificate(),
    );
    if (R.isFailure(verified)) {
      c.set("appStoreNotification", { result: "rejected" });
      return c.body(null, 400);
    }
    const { notificationUUID, notificationType, subtype, signedDate, data } = verified.value;
    const log = { notificationType, notificationSubtype: subtype };
    if (data !== undefined && data.bundleId !== c.env.APPLE_BUNDLE_ID) {
      c.set("appStoreNotification", { ...log, result: "rejected" });
      return c.body(null, 400);
    }
    // 取引を運ばない通知（TEST、更新の延長のまとめなど）は、どのサブスクリプションのものか分からないので案内できない
    if (data?.transaction === undefined) {
      c.set("appStoreNotification", { ...log, result: "unrouted" });
      return c.body(null, 200);
    }
    const transaction = readAppStoreSubscriptionTransaction(
      data.transaction,
      c.env.APPLE_BUNDLE_ID,
    );
    if (R.isFailure(transaction)) {
      c.set("appStoreNotification", { ...log, result: "rejected" });
      return c.body(null, 400);
    }
    const accountId = await routeAppStoreServerNotification(c.env.DB, transaction.value);
    if (accountId === undefined) {
      c.set("appStoreNotification", { ...log, result: "unrouted" });
      return c.body(null, 200);
    }
    c.set("accountId", accountId);
    const result = await getAccountDurableObject(
      c.env,
      accountId,
    ).receiveAppStoreServerNotification(accountId, {
      notificationUuid: notificationUUID,
      notificationType,
      notificationSubtype: subtype,
      signedAt: new Date(signedDate),
      transaction: transaction.value,
      gracePeriodExpiresAt:
        data.renewalInfo?.gracePeriodExpiresDate === undefined
          ? undefined
          : new Date(data.renewalInfo.gracePeriodExpiresDate),
    });
    c.set("appStoreNotification", { ...log, result });
    return c.body(null, result === "awaiting_revocation" ? 500 : 200);
  },
);
