import type { R } from "@praha/byethrow";
import { z } from "zod";
import type { AppStoreSignatureUnverifiedError } from "./app-store-signature-unverified-error";
import { appStoreEnvironmentSchema } from "./app-store-environment";
import { verifyAppStoreJws } from "./verify-app-store-jws";

// 端末が StoreKit から受け取った取引（jwsRepresentation）と、通知の中の取引（signedTransactionInfo）を読む。
// rootCertificate は、本番では appleRootCaG3、テストでは自分で作った鎖の根を渡す
export const verifyAppStoreTransaction = (
  signedTransaction: string,
  rootCertificate: string,
): R.ResultAsync<AppStoreTransaction, AppStoreSignatureUnverifiedError> =>
  verifyAppStoreJws(signedTransaction, rootCertificate, appStoreTransactionSchema);

// 時刻は UNIX 時刻のミリ秒
export type AppStoreTransaction = z.output<typeof appStoreTransactionSchema>;

const appStoreTransactionSchema = z
  .object({
    transactionId: z.string(),
    originalTransactionId: z.string(),
    bundleId: z.string(),
    productId: z.string(),
    purchaseDate: z.number(),
    expiresDate: z.number().optional(),
    // アプリが購入者のトークンを渡さなかった取引には無い
    appAccountToken: z.string().optional(),
    revocationDate: z.number().optional(),
    environment: appStoreEnvironmentSchema,
    transactionReason: z.enum(["PURCHASE", "RENEWAL"]),
  })
  .transform(({ expiresDate, appAccountToken, revocationDate, ...transaction }) => ({
    ...transaction,
    expiresDate,
    appAccountToken,
    revocationDate,
  }));
