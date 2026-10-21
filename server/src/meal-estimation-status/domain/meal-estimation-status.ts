// 食事の推定の状態。行を持たず、推定の出来事から出す
export type MealEstimationStatus =
  | "awaiting_photos"
  | "estimating"
  | "estimated"
  | "no_dishes"
  | "deferred_to_next_day"
  // サブスクリプション切れのため推定を始めず、買うのを待っている（いちばん新しい予定が保留）
  | "awaiting_subscription"
  | "failed";
