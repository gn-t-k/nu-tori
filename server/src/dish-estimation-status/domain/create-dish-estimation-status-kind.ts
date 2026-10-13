import type { DishStore } from "../../dish/domain/dish-store";
import { createServerOnlyKind } from "../../domain/sync-ledger/create-server-only-kind";
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
): RecordKind<"dish_estimation_status", never, DishEstimationStatus> =>
  createServerOnlyKind({
    name: "dish_estimation_status",
    whenGone: "deletion_mark",
    parent: { exists: dishStore.exists, hasDeletion: dishStore.hasDeletion },
    find: (dishId) => computeDishEstimationStatus(store.findSchedulesOfDish(dishId), now),
  });
