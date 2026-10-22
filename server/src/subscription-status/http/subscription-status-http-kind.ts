import { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { Subscription } from "../../subscription/domain/compute-subscription";
import { subscriptionPlans } from "../../subscription/domain/subscription-transaction-fact";
import type { SubscriptionStatus } from "../domain/subscription-status";

const freeTrialSchema = z
  .discriminatedUnion("type", [
    z.object({
      type: z.literal("available"),
      lastDay: z.string().openapi({
        description: "無料体験の最後の日（YYYY-MM-DD）。その日の終わりまでが無料体験中",
        example: "2026-11-30",
      }),
    }),
    z
      .object({ type: z.literal("used_by_earlier_account") })
      .openapi({ description: "作り直したアカウント。無料体験が無い" }),
  ])
  .openapi("SubscriptionStatusFreeTrial");

const billingGraceSchema = z
  .discriminatedUnion("type", [
    z.object({ type: z.literal("none") }),
    z.object({
      type: z.literal("granted"),
      endsAt: z.string().openapi({
        description: "請求の猶予の終わり（ISO 8601 の時刻）。期限より遅いときだけ届く",
        example: "2026-12-17T00:00:00.000Z",
      }),
    }),
  ])
  .openapi("SubscriptionStatusBillingGrace", {
    description:
      "端末はサブスクリプションの終わりを、granted ならその endsAt、none なら periodEndsAt として選ぶ（比べるのはサーバー）",
  });

const subscriptionSchema = z
  .discriminatedUnion("type", [
    z.object({ type: z.literal("none") }).openapi({
      description: "取り消されていない取引が無い（買っていない、またはすべて取り消された）",
    }),
    z.object({
      type: z.literal("subscribed"),
      plan: z.enum(subscriptionPlans).openapi({
        description:
          "期限がいちばん遅い取り消されていない取引の商品。月額（monthly）か年額（yearly）",
      }),
      periodEndsAt: z.string().openapi({
        description:
          "期限がいちばん遅い取り消されていない取引の期限（ISO 8601 の時刻）。更新日に使う",
        example: "2026-12-01T00:00:00.000Z",
      }),
      billingGrace: billingGraceSchema,
    }),
  ])
  .openapi("SubscriptionStatusSubscription");

// 取りに行く変更の record の形。値は null を持たず、その値が意味を持つ場合にだけ持つ（#647 の「同期」）
const subscriptionStatusRecordSchema = z
  .discriminatedUnion("type", [
    z
      .object({ type: z.literal("test_user") })
      .openapi({ description: "テストユーザー。いつもサブスクリプション中と同じに扱う" }),
    z.object({
      type: z.literal("regular"),
      freeTrial: freeTrialSchema,
      subscription: subscriptionSchema,
    }),
  ])
  .openapi({
    description:
      "kind が subscription_status の変更の record。recordId は最初のサインインの ID の1つだけで、消えない。日付と時刻は事実が変わったときだけ変わるので、端末は今日と比べて描く",
  });

export const subscriptionStatusHttpKind: HttpRecordKind<
  SubscriptionStatus,
  never,
  typeof subscriptionStatusRecordSchema
> = {
  // サーバーだけが書く種類なので、端末からの書き込みは届かない
  writes: undefined,
  recordSchema: subscriptionStatusRecordSchema,
  toRecord: (status) =>
    match(status)
      .with({ type: "test_user" }, () => ({ type: "test_user" as const }))
      .with({ type: "regular" }, ({ freeTrial, subscription }) => ({
        type: "regular" as const,
        freeTrial,
        subscription: toSubscriptionRecord(subscription),
      }))
      .exhaustive(),
};

const toSubscriptionRecord = (subscription: Subscription): z.input<typeof subscriptionSchema> =>
  match(subscription)
    .with({ type: "none" }, () => ({ type: "none" as const }))
    .with({ type: "subscribed" }, ({ plan, periodEndsAt, billingGrace }) => ({
      type: "subscribed" as const,
      plan,
      periodEndsAt: periodEndsAt.toISOString(),
      billingGrace: match(billingGrace)
        .with({ type: "none" }, () => ({ type: "none" as const }))
        .with({ type: "granted" }, ({ endsAt }) => ({
          type: "granted" as const,
          endsAt: endsAt.toISOString(),
        }))
        .exhaustive(),
    }))
    .exhaustive();
