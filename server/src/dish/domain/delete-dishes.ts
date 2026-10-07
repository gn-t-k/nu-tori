import type { RecordId } from "../../domain/record-id";
import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { IngredientStore } from "../../ingredient/domain/ingredient-store";
import type { DishStore } from "./dish-store";

// 料理と、その料理のすべての材料（前の推定の材料も）を、#332 の「消す順」で消す。料理を消す書き込みと食事を消す書き込みが使う。
// 親から書き、子から消す: 削除の印を控えつきで書き、修正の行を控えから探して消し、材料を消し、料理を消す。
// 修正の行は控えだけを指すので、材料の行を消す前に、記録の ID から探して消す
export const deleteDishes = (
  stores: { dish: DishStore; ingredient: IngredientStore },
  { dishIds, ingredientIds }: { dishIds: readonly RecordId[]; ingredientIds: readonly RecordId[] },
  receiptId: WriteReceiptId,
): void => {
  stores.dish.insertDeletions(dishIds, receiptId);
  stores.ingredient.insertDeletions(ingredientIds, receiptId);
  stores.ingredient.removeCorrections(ingredientIds);
  stores.dish.removeCorrections(dishIds);
  stores.ingredient.remove(ingredientIds);
  stores.dish.remove(dishIds);
};
