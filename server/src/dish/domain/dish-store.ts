import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { Dish, DishEstimationApplication, NewDish } from "./dish";

export type DishStore = {
  // 今の値（量と単位と版は出来事から出す）
  find: (id: string) => Dish | undefined;
  hasDeletion: (id: string) => boolean;
  findIdsOfMeal: (mealId: string) => string[];
  insert: (dish: NewDish) => void;
  // 当てた推定と推定の量を書く。材料はこのあとに、同じ推定の ID を付けて書く
  insertEstimationApplication: (application: DishEstimationApplication) => void;
  // 材料を先に消してから呼ぶ（材料の親は外部キーで守っている）。当てた推定と推定の量は CASCADE で消える
  remove: (ids: readonly string[]) => void;
  // 料理を書き換えた控えから、名前と量の修正の行を探して消す（比例の明細は CASCADE で消える）
  removeCorrections: (ids: readonly string[]) => void;
  // 消した書き込みの控えつきで、削除の印を書く
  insertDeletions: (ids: readonly string[], receiptId: WriteReceiptId) => void;
};
