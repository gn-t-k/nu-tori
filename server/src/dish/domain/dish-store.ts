import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { Dish } from "./dish";

export type DishStore = {
  find: (id: string) => Dish | undefined;
  hasDeletion: (id: string) => boolean;
  findIdsOfMeal: (mealId: string) => string[];
  insert: (dish: Dish) => void;
  // 材料を先に消してから呼ぶ（材料の親は外部キーで守っている）
  remove: (ids: readonly string[]) => void;
  // 削除の印と、消した書き込みの控えとのつなぎを書く
  insertDeletions: (ids: readonly string[], receiptId: WriteReceiptId) => void;
};
