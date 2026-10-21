import { ErrorFactory } from "@praha/error-factory";
import type { SubscriptionTransactionRejectedError } from "../../subscription/domain/read-app-store-subscription-transaction";

// Sentry に送る、扱えなかった App Store のサーバー通知（#647 の「観測」）。
// 署名つきの本文・購入者のトークン・Apple の sub を持たせないよう、断った理由と通知の種類だけを持ち、cause も付けない
export class AppStoreServerNotificationUnhandledError extends ErrorFactory({
  name: "AppStoreServerNotificationUnhandledError",
  message: "App Store のサーバー通知を扱えなかった",
  fields: ErrorFactory.fields<{
    // unverified: 署名を確かめられない。unrouted: どのアカウントにも案内できない。ほかは取引の写しを断った理由
    reason: "unverified" | "unrouted" | SubscriptionTransactionRejectedError["reason"];
    notificationType: string | undefined;
    notificationSubtype: string | undefined;
  }>(),
}) {}
