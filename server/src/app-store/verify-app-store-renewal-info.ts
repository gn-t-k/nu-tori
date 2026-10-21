import type { R } from "@praha/byethrow";
import { z } from "zod";
import type { AppStoreSignatureUnverifiedError } from "./app-store-signature-unverified-error";
import { verifyAppStoreJws } from "./verify-app-store-jws";

// 通知の中の更新の情報（signedRenewalInfo）を読む
export const verifyAppStoreRenewalInfo = (
  signedRenewalInfo: string,
  rootCertificate: string,
): R.ResultAsync<AppStoreRenewalInfo, AppStoreSignatureUnverifiedError> =>
  verifyAppStoreJws(signedRenewalInfo, rootCertificate, appStoreRenewalInfoSchema);

// 時刻は UNIX 時刻のミリ秒
export type AppStoreRenewalInfo = z.output<typeof appStoreRenewalInfoSchema>;

const appStoreRenewalInfoSchema = z
  .object({
    // 猶予に入っていないときは無い
    gracePeriodExpiresDate: z.number().optional(),
  })
  .transform(({ gracePeriodExpiresDate }) => ({ gracePeriodExpiresDate }));
