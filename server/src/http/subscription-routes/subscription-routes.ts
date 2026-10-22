import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { captureException } from "@sentry/cloudflare";
import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import { readAppStoreRootCertificate } from "../../app-store/app-store-root-certificate";
import { verifyAppStoreTransaction } from "../../app-store/verify-app-store-transaction";
import { recordIdSchema } from "../../domain/record-id";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { createAppAccountTokenStore } from "../../subscription/d1/create-app-account-token-store";
import { routeSubscriptionTransactionReport } from "../../subscription/d1/route-subscription-transaction-report";
import { readAppStoreSubscriptionTransaction } from "../../subscription/domain/read-app-store-subscription-transaction";
import { subscriptionTransactionReportTriggers } from "../../subscription/domain/subscription-transaction-fact";
import { authenticateAccount } from "../authenticate-account";
import { SubscriptionTransactionReportFailedError } from "./subscription-transaction-report-failed-error";
import { subscriptionTransactionRejectionCodes } from "./subscription-transaction-rejection-codes";
import { toChangeBody } from "../sync-routes/to-change-body";
import { subscriptionTransactionReportSchema } from "./subscription-transaction-report-schema";

// サブスクリプションを買う端末とのやりとり（#647 の「サーバーとのやりとり」）
export const subscriptionRoutes = new OpenAPIHono<{ Bindings: Env }>()
  .openapi(
    createRoute({
      method: "post",
      path: "/v1/app-account-token",
      operationId: "issueAppAccountToken",
      summary: "購入者のトークンを出す",
      description:
        "StoreKit で買うときに渡す購入者のトークン（appAccountToken）。まだ無ければ出し、2度目からは同じ値を返す",
      security: [{ session: [] }],
      middleware: [authenticateAccount] as const,
      responses: {
        200: {
          description: "購入者のトークン",
          content: {
            "application/json": {
              schema: z
                .object({
                  appAccountToken: z.string().openapi({
                    description: "UUID（小文字）",
                    example: "6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b",
                  }),
                })
                .openapi("AppAccountToken"),
            },
          },
        },
        401: { description: "セッションが無いか、切れている" },
        429: { description: "回数の歯止めにかかった" },
      },
    }),
    async (c) => {
      const appAccountToken = await createAppAccountTokenStore(c.env.DB).issue(c.var.accountId);
      return c.json({ appAccountToken }, 200);
    },
  )
  .openapi(
    createRoute({
      method: "post",
      path: "/v1/subscription-transactions",
      operationId: "reportSubscriptionTransaction",
      summary: "取引を知らせる",
      description:
        "端末が StoreKit から受け取った取引を知らせる。署名を確かめ、このアカウントに結びつけて書き、保留した推定を再開する。" +
        "端末は応答を受け取ってから Transaction.finish() を呼ぶ。同じ要求の ID の再送は、書かずに今の値を返す",
      security: [{ session: [] }],
      middleware: [authenticateAccount] as const,
      request: {
        body: {
          required: true,
          content: {
            "application/json": {
              schema: z.object({
                requestId: recordIdSchema.openapi({
                  description: "端末が振った要求の ID（UUID v4）。冪等の鍵にする",
                }),
                signedTransaction: z.string().openapi({
                  description: "StoreKit の Transaction の jwsRepresentation",
                }),
                trigger: z.enum(subscriptionTransactionReportTriggers).openapi({
                  description:
                    "purchase（買った直後）・restore（購入を復元）・transaction_updates（Transaction.updates と、終えていない取引）",
                }),
              }),
            },
          },
        },
      },
      responses: {
        200: {
          description: "結びつけたか、ほかのアカウントのものだった",
          content: { "application/json": { schema: subscriptionTransactionReportSchema } },
        },
        400: { description: "要求の形が違う" },
        401: { description: "セッションが無いか、切れている" },
        422: {
          description:
            "受け付けない取引。transaction_unverified（署名を確かめられない、ほかのアプリの取引）・environment_unsupported（環境が Production・Sandbox でない）・product_unknown（知らない商品）・expires_date_missing（期限が無い）",
          content: {
            "application/json": {
              schema: z
                .object({
                  code: z.enum(subscriptionTransactionRejectionCodes),
                })
                .openapi("SubscriptionTransactionRejection"),
            },
          },
        },
        429: { description: "回数の歯止めにかかった" },
      },
    }),
    async (c) => {
      const { requestId, signedTransaction, trigger } = c.req.valid("json");
      const verified = await verifyAppStoreTransaction(
        signedTransaction,
        readAppStoreRootCertificate(),
      );
      if (R.isFailure(verified)) {
        captureException(
          new SubscriptionTransactionReportFailedError({ code: "transaction_unverified" }),
        );
        return c.json({ code: "transaction_unverified" as const }, 422);
      }
      const read = readAppStoreSubscriptionTransaction(verified.value, c.env.APPLE_BUNDLE_ID);
      if (R.isFailure(read)) {
        const code = match(read.error.reason)
          .with("bundle_id_mismatch", () => "transaction_unverified" as const)
          .with(
            "environment_unsupported",
            "product_unknown",
            "expires_date_missing",
            (other) => other,
          )
          .exhaustive();
        // Sandbox の取引は、開発用のビルドで買うたびに本番のサーバーにも届くので、Workers Logs にだけ出す
        if (verified.value.environment !== "Sandbox") {
          captureException(new SubscriptionTransactionReportFailedError({ code }));
        }
        return c.json({ code }, 422);
      }
      const transaction = read.value;
      const routed = await routeSubscriptionTransactionReport(
        c.env.DB,
        c.var.accountId,
        transaction,
      );
      if (routed === "owned_by_other_account") {
        return c.json({ result: routed }, 200);
      }
      const records = await getAccountDurableObject(
        c.env,
        c.var.accountId,
      ).reportSubscriptionTransaction(c.var.accountId, { requestId, trigger, transaction });
      return c.json(
        {
          result: routed,
          changes: records.map(({ recordType, recordId, current }) =>
            toChangeBody(recordType, recordId, current),
          ),
        },
        200,
      );
    },
  );
