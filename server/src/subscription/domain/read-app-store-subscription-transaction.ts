import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { match } from "ts-pattern";
import type { AppStoreTransaction } from "../../app-store/verify-app-store-transaction";
import {
  type AppStoreSubscriptionEnvironment,
  appStoreProductPlans,
  type SubscriptionTransactionReason,
} from "./subscription";

// 書く取引の写し。署名を確かめた App Store の取引から、表に書く形にしたもの
export type AppStoreSubscriptionTransaction = {
  environment: AppStoreSubscriptionEnvironment;
  appStoreOriginalTransactionId: string;
  appStoreTransactionId: string;
  appStoreProductId: string;
  transactionReason: SubscriptionTransactionReason;
  purchasedAt: Date;
  expiresAt: Date;
  // 買うときに渡した購入者のトークン（小文字）。渡さずに買った取引には無い
  appAccountToken: string | undefined;
};

// 署名を確かめた取引のうち、このアプリのサブスクリプションの取引だけを受け付ける。
// 知らない商品の取引は書かない（サブスクリプションの状態の計算が、知らない商品の取引で投げるため）
export const readAppStoreSubscriptionTransaction = (
  transaction: AppStoreTransaction,
  bundleId: string,
): R.Result<AppStoreSubscriptionTransaction, SubscriptionTransactionRejectedError> => {
  const environment = match(transaction.environment)
    .returnType<AppStoreSubscriptionEnvironment | undefined>()
    .with("Production", () => "production")
    .with("Sandbox", () => "sandbox")
    .with("Xcode", "LocalTesting", () => undefined)
    .exhaustive();
  if (environment === undefined) {
    return R.fail(new SubscriptionTransactionRejectedError({ reason: "environment_unsupported" }));
  }
  if (transaction.bundleId !== bundleId) {
    return R.fail(new SubscriptionTransactionRejectedError({ reason: "bundle_id_mismatch" }));
  }
  if (
    !Object.hasOwn(appStoreProductPlans, transaction.productId) ||
    transaction.expiresDate === undefined
  ) {
    return R.fail(new SubscriptionTransactionRejectedError({ reason: "product_unknown" }));
  }
  return R.succeed({
    environment,
    appStoreOriginalTransactionId: transaction.originalTransactionId,
    appStoreTransactionId: transaction.transactionId,
    appStoreProductId: transaction.productId,
    transactionReason: match(transaction.transactionReason)
      .returnType<SubscriptionTransactionReason>()
      .with("PURCHASE", () => "purchase")
      .with("RENEWAL", () => "renewal")
      .exhaustive(),
    purchasedAt: new Date(transaction.purchaseDate),
    expiresAt: new Date(transaction.expiresDate),
    appAccountToken: transaction.appAccountToken?.toLowerCase(),
  });
};

// 環境が Production・Sandbox でない（Xcode の StoreKit のテストなど）、ほかのアプリの取引、知らない商品の取引
export class SubscriptionTransactionRejectedError extends ErrorFactory({
  name: "SubscriptionTransactionRejectedError",
  message: "受け付けない取引",
  fields: ErrorFactory.fields<{
    reason: "environment_unsupported" | "bundle_id_mismatch" | "product_unknown";
  }>(),
}) {}
