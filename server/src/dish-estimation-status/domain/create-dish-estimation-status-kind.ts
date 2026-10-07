import type { DishStore } from "../../dish/domain/dish-store";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import { computeDishEstimationStatus } from "./compute-dish-estimation-status";
import type { DishEstimationStatus } from "./dish-estimation-status";
import type { DishEstimationStatusStore } from "./dish-estimation-status-store";

// 料理ごとの推定の状態の種類。サーバーだけが書く。記録の ID は料理の ID で、料理が消えたら料理の削除の印から削除の印を返す。
// 料理が対象の予定が無い料理（推定し直しをしていない料理）は値を持たず、変更の並びにも載せない。now は今の状態を決める時刻
export const createDishEstimationStatusKind = (
  dishStore: DishStore,
  store: DishEstimationStatusStore,
  now: Date,
): RecordKind<"dish_estimation_status", never, DishEstimationStatus> => ({
  name: "dish_estimation_status",
  writes: undefined,
  follows: undefined,
  whenGone: "deletion_mark",
  readCurrent: (dishId): CurrentRecord<DishEstimationStatus> => {
    if (!dishStore.exists(dishId)) {
      return dishStore.hasDeletion(dishId) ? { status: "deleted" } : { status: "absent" };
    }
    const status = computeDishEstimationStatus(store.findSchedulesOfDish(dishId), now);
    return status === undefined ? { status: "absent" } : { status: "value", value: status };
  },
});
