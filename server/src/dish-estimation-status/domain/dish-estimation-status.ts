import type { ScheduledEstimationStatus } from "../../estimation/domain/scheduled-estimation-status";

// 料理ごとの推定の状態。行を持たず、料理が対象の推定の出来事から出す（#332 の「料理ごとの推定の状態の出し方」）
export type DishEstimationStatus = ScheduledEstimationStatus;
