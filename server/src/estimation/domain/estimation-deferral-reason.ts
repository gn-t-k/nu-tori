// 推定を始めなかった理由。1日の回数の上限で予定を次の日に回したか、サブスクリプション切れで保留したか
export type EstimationDeferralReason = "daily_limit" | "subscription_expired";
