// 料理ごとの推定の状態。行を持たず、料理が対象の推定の出来事から出す（#332 の「料理ごとの推定の状態の出し方」）。
// 食事の推定の状態から「写真を待っている」を除いたもの
export type DishEstimationStatus =
  | "estimating"
  | "deferred_to_next_day"
  | "estimated"
  | "no_dishes"
  | "failed";
