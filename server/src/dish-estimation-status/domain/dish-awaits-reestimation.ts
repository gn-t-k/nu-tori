import { match } from "ts-pattern";
import type { RecordId } from "../../domain/record-id";
import { computeEstimationStatus } from "../../estimation/domain/compute-estimation-status";
import type { DishEstimationStatusStore } from "./dish-estimation-status-store";

// 料理が推定し直しを待っているか（推定中・翌日に推定・サブスクリプションを待っている）。待っている料理は、消すことしかできない（#381）。
// 推定の状態は行を持たないので、今の表から毎回出す
export const dishAwaitsReestimation = (
  store: DishEstimationStatusStore,
  dishId: RecordId,
): boolean =>
  match(computeEstimationStatus(store.findSchedulesOfDish(dishId)))
    .with("estimating", "deferred_to_next_day", "awaiting_subscription", () => true)
    .with("estimated", "no_dishes", "failed", undefined, () => false)
    .exhaustive();
