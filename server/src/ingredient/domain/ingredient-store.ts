import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { Ingredient } from "./ingredient";

export type IngredientStore = {
  // 今の材料（料理のいちばん新しい当てた推定の材料）だけを返す
  find: (id: string) => Ingredient | undefined;
  // 削除の印があるか、前の推定の材料（今の材料でない）なら true
  hasDeletion: (id: string) => boolean;
  // 食事の料理の材料（前の推定の材料も）
  findIdsOfMeal: (mealId: string) => string[];
  // 料理の材料（前の推定の材料も）
  findIdsOfDish: (dishId: string) => string[];
  // 出どころと栄養の値ごと書く。料理の当てた推定を先に書いてから呼ぶ
  insert: (ingredient: Ingredient) => void;
  // 出どころと栄養の値は CASCADE で消える
  remove: (ids: readonly string[]) => void;
  // 材料を書き換えた控えから、量の修正の行を探して消す
  removeCorrections: (ids: readonly string[]) => void;
  // 消した書き込みの控えつきで、削除の印を書く
  insertDeletions: (ids: readonly string[], receiptId: WriteReceiptId) => void;
};
