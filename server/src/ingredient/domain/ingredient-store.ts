import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { Ingredient } from "./ingredient";

export type IngredientStore = {
  find: (id: string) => Ingredient | undefined;
  hasDeletion: (id: string) => boolean;
  // 食事の料理の材料
  findIdsOfMeal: (mealId: string) => string[];
  // 出どころと栄養の値ごと書く
  insert: (ingredient: Ingredient) => void;
  // 出どころと栄養の値は CASCADE で消える
  remove: (ids: readonly string[]) => void;
  // 削除の印と、消した書き込みの控えとのつなぎを書く
  insertDeletions: (ids: readonly string[], receiptId: WriteReceiptId) => void;
};
