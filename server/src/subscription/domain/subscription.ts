// サブスクリプションの区分の値と、判定に使う事実の型（#647 の「判定の決まり」）。
// 区分の値は列に CHECK を書かないので、書く口がこの一覧で確かめ、表の宣言は text({ enum }) でここから引く

// 表に書く App Store の環境。届く値（src/app-store/app-store-environment.ts の Production・Sandbox）を小文字にしたもの。
// Xcode・LocalTesting の取引は断るので持たない
export const appStoreSubscriptionEnvironments = ["production", "sandbox"] as const;
export type AppStoreSubscriptionEnvironment = (typeof appStoreSubscriptionEnvironments)[number];

// 取引の理由（App Store の transactionReason）
export const subscriptionTransactionReasons = ["purchase", "renewal"] as const;
export type SubscriptionTransactionReason = (typeof subscriptionTransactionReasons)[number];

// 端末が取引を知らせたきっかけ。買った直後、購入を復元、Transaction.updates と終えていない取引
export const subscriptionTransactionReportTriggers = [
  "purchase",
  "restore",
  "transaction_updates",
] as const;
export type SubscriptionTransactionReportTrigger =
  (typeof subscriptionTransactionReportTriggers)[number];

export const subscriptionPlans = ["monthly", "yearly"] as const;
export type SubscriptionPlan = (typeof subscriptionPlans)[number];

// App Store Connect の商品の ID と、月額か年額か。表には持たない（#647 の「お金と回数」）
export const appStoreProductPlans: Readonly<Record<string, SubscriptionPlan>> = {
  "app.nu-tori.subscription.monthly": "monthly",
  "app.nu-tori.subscription.yearly": "yearly",
};

// 判定に使う取引。取り消しと、ついた請求の猶予の終わりを持つ
export type SubscriptionTransactionFact = {
  appStoreProductId: string;
  expiresAt: Date;
  // 取り消しごとに、戻されたか
  revocations: readonly { reversed: boolean }[];
  // ついた請求の失敗のうち、猶予があるものの終わり
  gracePeriodExpiresAts: readonly Date[];
};
