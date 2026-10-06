import { match } from "ts-pattern";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import type { IngredientStore } from "../../ingredient/domain/ingredient-store";
import { deleteDishes } from "./delete-dishes";
import type { Dish } from "./dish";
import type { DishStore } from "./dish-store";
import { type DishWrite, dishWriteTypes } from "./dish-write";

// 料理の種類。サーバーが推定の完了で作り、端末が消す
export const createDishKind = (
  stores: DishKindStores,
): RecordKind<"dish", DishWrite, Dish, AddedRecordType> => ({
  name: "dish",
  writes: {
    isWrite: (write): write is DishWrite => dishWriteTypes.includes(write.type),
    decide: (write) =>
      match(write)
        .with({ type: "delete_dish" }, ({ dishId }) => decideDelete(stores, dishId))
        .exhaustive(),
  },
  follows: undefined,
  whenGone: "deletion_mark",
  readCurrent: (dishId): CurrentRecord<Dish> => {
    const dish = stores.dish.find(dishId);
    if (dish !== undefined) {
      return { status: "value", value: dish };
    }
    return stores.dish.hasDeletion(dishId) ? { status: "deleted" } : { status: "absent" };
  },
});

// 料理の書き込みが、料理のほかに変える記録の種類
type AddedRecordType = "ingredient";

type DishKindStores = { dish: DishStore; ingredient: IngredientStore };

// 受け付けられないことが無い書き込み（docs/agents/sync.md）。料理がまだ届いていなくても印を残し、
// あとから届く作る書き込みで生き返らせない。材料の変更は、前の推定の材料も含めて1つずつ足す
const decideDelete = (stores: DishKindStores, dishId: string): WriteDecision<AddedRecordType> => {
  if (stores.dish.hasDeletion(dishId)) {
    return {
      writeKind: "delete",
      recordId: dishId,
      outcome: { result: "ignored_tombstone" },
      changedRecordId: dishId,
      addedChanges: [],
      usageEvents: [],
      commit: () => undefined,
    };
  }
  const ingredientIds = stores.ingredient.findIdsOfDish(dishId);
  return {
    writeKind: "delete",
    recordId: dishId,
    outcome: { result: "applied" },
    changedRecordId: dishId,
    addedChanges: ingredientIds.map((recordId) => ({ recordType: "ingredient", recordId })),
    usageEvents: [],
    commit: (receiptId) => {
      deleteDishes(stores, { dishIds: [dishId], ingredientIds }, receiptId);
    },
  };
};
