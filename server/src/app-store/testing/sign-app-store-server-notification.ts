import { env } from "cloudflare:workers";
import { signAppStoreJws } from "./sign-app-store-jws";
import type { TestSigner } from "./sign-app-store-jws";

// App Store のサーバー通知の本文（ResponseBodyV2DecodedPayload）の形。
// data の取引と更新の情報は、signAppStoreTransaction・signAppStoreRenewalInfo で作った JWS を渡す
export type AppStoreServerNotificationPayload = {
  notificationType: string;
  subtype?: string | undefined;
  notificationUUID: string;
  data?: AppStoreServerNotificationDataPayload | undefined;
  version: string;
  signedDate: number;
};

type AppStoreServerNotificationDataPayload = {
  appAppleId?: number | undefined;
  bundleId: string;
  bundleVersion?: string | undefined;
  environment: string;
  signedTransactionInfo?: string | undefined;
  signedRenewalInfo?: string | undefined;
  status?: number | undefined;
};

export const signAppStoreServerNotification = (
  chain: TestSigner,
  overrides: Partial<AppStoreServerNotificationPayload> = {},
): Promise<string> =>
  signAppStoreJws(chain, {
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    notificationUUID: "0b6c3e1a-2f4d-4c8e-9a7b-5d6e7f8a9b0c",
    data: {
      appAppleId: 1234567890,
      bundleId: env.APPLE_BUNDLE_ID,
      bundleVersion: "1",
      environment: "Production",
      status: 1,
    },
    version: "2.0",
    signedDate: Date.parse("2026-10-20T00:00:02Z"),
    ...overrides,
  });
