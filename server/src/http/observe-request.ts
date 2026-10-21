import { setTag } from "@sentry/cloudflare";
import { createMiddleware } from "hono/factory";
import { routePath } from "hono/route";
import type { AccountRequestLog } from "../account/domain/account-response";

// Durable Object の答えが持つ、要求ごとのログに足す値。受け口が置き、observeRequest が出す
export type RequestLogVariables = { requestLog?: AccountRequestLog };

// App Store のサーバー通知の受け口が置く、通知の種類と結果。本文は出さない
export type AppStoreNotificationLogVariables = {
  appStoreNotification?: {
    notificationType?: string;
    notificationSubtype?: string | undefined;
    // rejected: 断った。unrouted: 案内できず何も残さない。duplicate: 受け取り済み。awaiting_revocation: 戻しを待つ
    result: "written" | "duplicate" | "unrouted" | "awaiting_revocation" | "rejected";
  };
};

// 要求 ID は Cloudflare の Ray ID にし、Workers Logs と Sentry の報告を同じ ID で辿れるようにする。
// 失敗した段は、例外の stage の欄に持たせる（Durable Object の RPC を越えても独自の欄は届く）。
// ビルド番号は、古いビルドを締め出したとき（426）だけ足す
export const observeRequest = createMiddleware<{
  Bindings: Env;
  Variables: { accountId?: string; unsupportedAppBuild?: number } & RequestLogVariables &
    AppStoreNotificationLogVariables;
}>(async (c, next) => {
  // oxlint-disable-next-line nu-tori/no-random-uuid -- ログを結ぶ ID で、DB にも API にも出さない
  const requestId = c.req.header("cf-ray") ?? crypto.randomUUID();
  setTag("requestId", requestId);
  const startedAt = Date.now();
  await next();
  console.log({
    requestId,
    accountId: c.get("accountId"),
    route: `${c.req.method} ${routePath(c, -1)}`,
    status: c.res.status,
    appBuild: c.get("unsupportedAppBuild"),
    error: c.error?.name,
    failedStage: c.error !== undefined && "stage" in c.error ? c.error.stage : undefined,
    reviewedWeekCount: c.get("requestLog")?.reviewedWeekCount,
    notificationType: c.get("appStoreNotification")?.notificationType,
    notificationSubtype: c.get("appStoreNotification")?.notificationSubtype,
    notificationResult: c.get("appStoreNotification")?.result,
    durationMs: Date.now() - startedAt,
  });
});
