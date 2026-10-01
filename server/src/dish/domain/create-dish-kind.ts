import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { Dish } from "./dish";
import type { DishStore } from "./dish-store";

// 料理の種類。サーバーだけが書く（推定の完了で作り、食事の削除で消す）
export const createDishKind = (store: DishStore): RecordKind<"dish", never, Dish> => ({
  name: "dish",
  writes: undefined,
  readCurrent: (dishId): CurrentRecord<Dish> => {
    const dish = store.find(dishId);
    if (dish !== undefined) {
      return { status: "value", value: dish };
    }
    return store.hasDeletion(dishId) ? { status: "deleted" } : { status: "absent" };
  },
});
