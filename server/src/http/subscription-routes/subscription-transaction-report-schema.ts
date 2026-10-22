import { z } from "@hono/zod-openapi";

// 取引の知らせの応答。結果の値は、増えても古い版のアプリが読めるよう判別する
export const subscriptionTransactionReportSchema = z
  .discriminatedUnion("result", [
    z
      .object({
        result: z.literal("linked"),
        changes: z
          .array(
            z
              .object({
                kind: z.string().openapi({
                  description:
                    "subscription_status・meal_estimation_status・dish_estimation_status",
                  example: "subscription_status",
                }),
                recordId: z.string(),
                record: z.record(z.string(), z.unknown()),
              })
              .openapi("SubscriptionTransactionReportChange", {
                description:
                  "取りに行く変更（SyncChange）から通し番号を除いた形で、record は種類ごとの SubscriptionStatusRecord・MealEstimationStatusRecord・DishEstimationStatusRecord",
              }),
          )
          .openapi({
            description:
              "端末はキャッシュに書く（同じ記録は同期でも届く）。並びは、サブスクリプションの状態、再開した食事・料理の推定の状態",
          }),
      })
      .openapi("LinkedSubscriptionTransactionReport", {
        description: "このアカウントに結びつけた。同じ要求の ID の再送を含む",
      }),
    z
      .object({ result: z.literal("owned_by_other_account") })
      .openapi("OwnedByOtherAccountSubscriptionTransactionReport", {
        description: "ほかの nu-tori のアカウントのサブスクリプション。何も書いていない",
      }),
  ])
  .openapi("SubscriptionTransactionReport");
