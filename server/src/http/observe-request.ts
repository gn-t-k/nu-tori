import { setTag } from "@sentry/cloudflare";
import { createMiddleware } from "hono/factory";
import { routePath } from "hono/route";
import { match, P } from "ts-pattern";
import type { AccountRequestLog } from "../account/domain/account-response";

// Durable Object の答えが持つ、要求ごとのログに足す値。受け口が置き、observeRequest が出す
export type RequestLogVariables = { requestLog?: AccountRequestLog };

// App Store のサーバー通知の受け口が置く、通知の種類と結果。本文は出さない。
// 署名を確かめられないときは、種類を読めないので断ったことだけを持つ
export type AppStoreNotificationLogVariables = {
  appStoreNotification?:
    | { signature: "unverified"; result: "rejected" }
    | {
        signature: "verified";
        notificationType: string;
        notificationSubtype: string | undefined;
        // rejected: 断った。unrouted: 案内できず何も残さない。duplicate: 受け取り済み。awaiting_revocation: 戻しを待つ
        result: "written" | "duplicate" | "unrouted" | "awaiting_revocation" | "rejected";
      };
};

// App Store の通知と端末の取引の知らせの受け口が置く、取引に購入者のトークン（appAccountToken）があったか。値は出さない。
// 通知がどのアカウントにも案内できなかったとき、トークンが無かったのか、持ち主が無かったのかを分けるため（#1025）
export type SubscriptionTransactionLogVariables = {
  subscriptionTransaction?: { hasAppAccountToken: boolean };
};

// 要求 ID は Cloudflare の Ray ID にし、Workers Logs と Sentry の報告を同じ ID で辿れるようにする。
// 失敗した段は、例外の stage の欄に持たせる（Durable Object の RPC を越えても独自の欄は届く）。
// ビルド番号は、古いビルドを締め出したとき（426）だけ足す
export const observeRequest = createMiddleware<{
  Bindings: Env;
  Variables: { accountId?: string; unsupportedAppBuild?: number } & RequestLogVariables &
    AppStoreNotificationLogVariables &
    SubscriptionTransactionLogVariables;
}>(async (c, next) => {
  // oxlint-disable-next-line nu-tori/no-random-uuid -- ログを結ぶ ID で、DB にも API にも出さない
  const requestId = c.req.header("cf-ray") ?? crypto.randomUUID();
  setTag("requestId", requestId);
  const startedAt = Date.now();
  await next();
  const appStoreNotification = c.get("appStoreNotification");
  const notificationKind = match(appStoreNotification)
    .with({ signature: "verified" }, ({ notificationType, notificationSubtype }) => ({
      notificationType,
      notificationSubtype,
    }))
    .with({ signature: "unverified" }, P.nullish, () => ({
      notificationType: undefined,
      notificationSubtype: undefined,
    }))
    .exhaustive();
  console.log({
    requestId,
    accountId: c.get("accountId"),
    route: `${c.req.method} ${routePath(c, -1)}`,
    status: c.res.status,
    appBuild: c.get("unsupportedAppBuild"),
    error: c.error?.name,
    failedStage: c.error !== undefined && "stage" in c.error ? c.error.stage : undefined,
    reviewedWeekCount: c.get("requestLog")?.reviewedWeekCount,
    notificationType: notificationKind.notificationType,
    notificationSubtype: notificationKind.notificationSubtype,
    notificationResult: appStoreNotification?.result,
    hasAppAccountToken: c.get("subscriptionTransaction")?.hasAppAccountToken,
    durationMs: Date.now() - startedAt,
  });
});
