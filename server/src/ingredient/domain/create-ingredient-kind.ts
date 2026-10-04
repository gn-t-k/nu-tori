import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { Ingredient } from "./ingredient";
import type { IngredientStore } from "./ingredient-store";

// 材料の種類。サーバーだけが書く（推定の完了で作り、食事の削除で消す）
export const createIngredientKind = (
  store: IngredientStore,
): RecordKind<"ingredient", never, Ingredient> => ({
  name: "ingredient",
  writes: undefined,
  follows: undefined,
  deliversAbsence: false,
  readCurrent: (ingredientId): CurrentRecord<Ingredient> => {
    const ingredient = store.find(ingredientId);
    if (ingredient !== undefined) {
      return { status: "value", value: ingredient };
    }
    return store.hasDeletion(ingredientId) ? { status: "deleted" } : { status: "absent" };
  },
});
