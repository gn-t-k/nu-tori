// 予定から出す推定の状態。食事の推定の状態から「写真を待っている」を除いたもので、料理ごとの推定の状態と同じ
export type ScheduledEstimationStatus =
  | "estimating"
  | "deferred_to_next_day"
  // サブスクリプション切れのため推定を始めず、買うのを待っている（いちばん新しい予定が保留）
  | "awaiting_subscription"
  | "estimated"
  | "no_dishes"
  | "failed";
