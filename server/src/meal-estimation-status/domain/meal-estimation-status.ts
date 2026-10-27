import type { ScheduledEstimationStatus } from "../../estimation/domain/compute-estimation-status";

// 食事の推定の状態。行を持たず、推定の出来事から出す。サブスクリプションを待っているは、サブスクリプション切れのため推定を始めず、
// 買うのを待っている（いちばん新しい予定が保留）
export type MealEstimationStatus = "awaiting_photos" | ScheduledEstimationStatus;
