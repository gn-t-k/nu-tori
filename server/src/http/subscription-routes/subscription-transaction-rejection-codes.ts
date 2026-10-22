// 取引の知らせを 422 で断るときの code。応答のスキーマと、Sentry に送るエラーが同じ並びを使う。
// transaction_unverified: 署名を確かめられない、ほかのアプリの取引。environment_unsupported: 環境が Production・Sandbox でない。
// product_unknown: 知らない商品。expires_date_missing: 期限が無い（自動更新のサブスクリプションの取引でない）
export const subscriptionTransactionRejectionCodes = [
  "transaction_unverified",
  "environment_unsupported",
  "product_unknown",
  "expires_date_missing",
] as const;

export type SubscriptionTransactionRejectionCode =
  (typeof subscriptionTransactionRejectionCodes)[number];
