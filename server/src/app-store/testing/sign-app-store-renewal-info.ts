import { signAppStoreJws } from "./sign-app-store-jws";
import type { TestSigner } from "./sign-app-store-jws";

// App Store が送る更新の情報（JWSRenewalInfoDecodedPayload）の形。読まない項目も、届く形をまねて載せる
export type AppStoreRenewalInfoPayload = {
  originalTransactionId: string;
  autoRenewProductId: string;
  productId: string;
  autoRenewStatus: number;
  gracePeriodExpiresDate?: number | undefined;
  isInBillingRetryPeriod?: boolean | undefined;
  signedDate: number;
  environment: string;
  recentSubscriptionStartDate: number;
  renewalDate: number;
};

export const signAppStoreRenewalInfo = (
  chain: TestSigner,
  overrides: Partial<AppStoreRenewalInfoPayload> = {},
): Promise<string> =>
  signAppStoreJws(chain, {
    originalTransactionId: "2000000000000001",
    autoRenewProductId: "app.nu_tori.subscription.monthly",
    productId: "app.nu_tori.subscription.monthly",
    autoRenewStatus: 1,
    signedDate: Date.parse("2026-10-20T00:00:01Z"),
    environment: "Production",
    recentSubscriptionStartDate: Date.parse("2026-10-20T00:00:00Z"),
    renewalDate: Date.parse("2026-11-20T00:00:00Z"),
    ...overrides,
  });
