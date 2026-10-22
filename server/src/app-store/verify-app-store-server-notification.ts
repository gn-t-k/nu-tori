import { R } from "@praha/byethrow";
import { z } from "zod";
import type { AppStoreSignatureUnverifiedError } from "./app-store-signature-unverified-error";
import { appStoreEnvironmentSchema } from "./app-store-environment";
import type { AppStoreEnvironment } from "./app-store-environment";
import { verifyAppStoreJws } from "./verify-app-store-jws";
import { verifyAppStoreRenewalInfo } from "./verify-app-store-renewal-info";
import type { AppStoreRenewalInfo } from "./verify-app-store-renewal-info";
import { verifyAppStoreTransaction } from "./verify-app-store-transaction";
import type { AppStoreTransaction } from "./verify-app-store-transaction";

// App Store のサーバー通知の本文（signedPayload）を読む。中の取引と更新の情報も、同じ根で確かめてから読む。
// rootCertificate は、本番では appleRootCaG3、テストでは自分で作った鎖の根を渡す
export const verifyAppStoreServerNotification = (
  signedPayload: string,
  rootCertificate: string,
): R.ResultAsync<AppStoreServerNotification, AppStoreSignatureUnverifiedError> =>
  R.pipe(
    verifyAppStoreJws(signedPayload, rootCertificate, notificationSchema),
    R.andThen(({ notificationUUID, notificationType, subtype, signedDate, data }) =>
      R.pipe(
        data === undefined ? R.succeed(undefined) : verifyData(data, rootCertificate),
        R.map((verifiedData) => ({
          notificationUUID,
          notificationType,
          subtype,
          signedDate,
          data: verifiedData,
        })),
      ),
    ),
  );

// 時刻は UNIX 時刻のミリ秒。notificationType と subtype は Apple が増やしうるので、文字列のまま持つ
export type AppStoreServerNotification = {
  notificationUUID: string;
  notificationType: string;
  subtype: string | undefined;
  signedDate: number;
  // 更新の延長のまとめ（summary）や、外部の購入の通知には無い
  data:
    | {
        bundleId: string;
        environment: AppStoreEnvironment;
        transaction: AppStoreTransaction | undefined;
        renewalInfo: AppStoreRenewalInfo | undefined;
      }
    | undefined;
};

const notificationSchema = z.object({
  notificationUUID: z.string(),
  notificationType: z.string(),
  subtype: z.string().optional(),
  signedDate: z.number(),
  data: z
    .object({
      bundleId: z.string(),
      environment: appStoreEnvironmentSchema,
      signedTransactionInfo: z.string().optional(),
      signedRenewalInfo: z.string().optional(),
    })
    .optional(),
});

const verifyData = (
  {
    bundleId,
    environment,
    signedTransactionInfo,
    signedRenewalInfo,
  }: NonNullable<z.output<typeof notificationSchema>["data"]>,
  rootCertificate: string,
): R.ResultAsync<
  NonNullable<AppStoreServerNotification["data"]>,
  AppStoreSignatureUnverifiedError
> =>
  R.pipe(
    R.do(),
    R.bind("transaction", () =>
      signedTransactionInfo === undefined
        ? R.succeed(undefined)
        : verifyAppStoreTransaction(signedTransactionInfo, rootCertificate),
    ),
    R.bind("renewalInfo", () =>
      signedRenewalInfo === undefined
        ? R.succeed(undefined)
        : verifyAppStoreRenewalInfo(signedRenewalInfo, rootCertificate),
    ),
    R.map(({ transaction, renewalInfo }) => ({ bundleId, environment, transaction, renewalInfo })),
  );
