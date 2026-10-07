import type { RecordId } from "../../domain/record-id";
import { computeDishEstimationStatus } from "./compute-dish-estimation-status";
import type { DishEstimationStatusStore } from "./dish-estimation-status-store";

// 料理が推定し直しを待っているか（推定中・翌日に推定）。待っている料理は、消すことしかできない（#381）。
// 推定の状態は行を持たないので、今の表から毎回出す
export const dishAwaitsReestimation = (
  store: DishEstimationStatusStore,
  dishId: RecordId,
  now: Date,
): boolean => {
  const status = computeDishEstimationStatus(store.findSchedulesOfDish(dishId), now);
  return status === "estimating" || status === "deferred_to_next_day";
};
