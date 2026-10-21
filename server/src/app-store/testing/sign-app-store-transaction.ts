import { env } from "cloudflare:workers";
import { signAppStoreJws } from "./sign-app-store-jws";
import type { TestSigner } from "./sign-app-store-jws";

// App Store が送る取引（JWSTransactionDecodedPayload）の形。読まない項目も、届く形をまねて載せる
export type AppStoreTransactionPayload = {
  transactionId: string;
  originalTransactionId: string;
  webOrderLineItemId: string;
  bundleId: string;
  productId: string;
  subscriptionGroupIdentifier: string;
  purchaseDate: number;
  originalPurchaseDate: number;
  expiresDate?: number | undefined;
  quantity: number;
  type: string;
  appAccountToken?: string | undefined;
  inAppOwnershipType: string;
  signedDate: number;
  revocationReason?: number | undefined;
  revocationDate?: number | undefined;
  transactionReason: string;
  environment: string;
  storefront: string;
  storefrontId: string;
  price: number;
  currency: string;
};

export const signAppStoreTransaction = (
  chain: TestSigner,
  overrides: Partial<AppStoreTransactionPayload> = {},
): Promise<string> =>
  signAppStoreJws(chain, {
    transactionId: "2000000000000001",
    originalTransactionId: "2000000000000001",
    webOrderLineItemId: "2000000000000002",
    bundleId: env.APPLE_BUNDLE_ID,
    productId: "app.nu-tori.subscription.monthly",
    subscriptionGroupIdentifier: "21000000",
    purchaseDate: Date.parse("2026-10-20T00:00:00Z"),
    originalPurchaseDate: Date.parse("2026-10-20T00:00:00Z"),
    expiresDate: Date.parse("2026-11-20T00:00:00Z"),
    quantity: 1,
    type: "Auto-Renewable Subscription",
    appAccountToken: "6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b",
    inAppOwnershipType: "PURCHASED",
    signedDate: Date.parse("2026-10-20T00:00:01Z"),
    transactionReason: "PURCHASE",
    environment: "Production",
    storefront: "JPN",
    storefrontId: "143462",
    price: 480000,
    currency: "JPY",
    ...overrides,
  });
