import type { RecordId } from "../../domain/record-id";
import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { Ingredient, NewIngredient } from "./ingredient";

export type IngredientStore = {
  // 今の材料（料理のいちばん新しい当てた推定の材料）だけを返す。量は今の量
  find: (id: RecordId) => Ingredient | undefined;
  // 削除の印があるか、前の推定の材料（今の材料でない）なら true
  hasDeletion: (id: RecordId) => boolean;
  // 推定し直しで置き換わった前の材料（行はあり、料理のいちばん新しい当てた推定の材料でない）なら true
  isReplaced: (id: RecordId) => boolean;
  // 食事の料理の材料（前の推定の材料も）
  findIdsOfMeal: (mealId: RecordId) => RecordId[];
  // 料理の材料（前の推定の材料も）
  findIdsOfDish: (dishId: RecordId) => RecordId[];
  // 料理の今の材料（いちばん新しい当てた推定の材料）
  findCurrentIdsOfDish: (dishId: RecordId) => RecordId[];
  // 出どころと栄養の値ごと書く。料理の当てた推定を先に書いてから呼ぶ
  insert: (ingredient: NewIngredient) => void;
  // 材料を直した書き込みの控えに、直した量を書く（材料は控えの record_id）
  insertQuantityCorrection: (receiptId: WriteReceiptId, quantity: number) => void;
  // 出どころと栄養の値は CASCADE で消える
  remove: (ids: readonly RecordId[]) => void;
  // 材料を書き換えた控えから、量の修正の行を探して消す
  removeCorrections: (ids: readonly RecordId[]) => void;
  // 消した書き込みの控えつきで、削除の印を書く
  insertDeletions: (ids: readonly RecordId[], receiptId: WriteReceiptId) => void;
};
