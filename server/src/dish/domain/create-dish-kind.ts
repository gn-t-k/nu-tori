import { match } from "ts-pattern";
import { isWithinAcceptedRange } from "../../domain/is-within-accepted-range";
import type { RejectionReason } from "../../domain/rejection-reason";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import type { IngredientStore } from "../../ingredient/domain/ingredient-store";
import { deleteDishes } from "./delete-dishes";
import type { Dish } from "./dish";
import type { DishStore } from "./dish-store";
import { type DishQuantityCorrection, type DishWrite, dishWriteTypes } from "./dish-write";

// 料理の種類。サーバーが推定の完了で作り、端末が名前と量を直し、消す
export const createDishKind = (
  stores: DishKindStores,
): RecordKind<"dish", DishWrite, Dish, AddedRecordType> => ({
  name: "dish",
  writes: {
    isWrite: (write): write is DishWrite => dishWriteTypes.includes(write.type),
    decide: (write) =>
      match(write)
        .with({ type: "delete_dish" }, ({ dishId }) => decideDelete(stores, dishId))
        .with({ type: "update_dish" }, (update) => decideUpdate(stores, update))
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

// 名前と量は、今の値と違う分だけ修正の出来事として足す。比例させた材料の量は端末が出したものを書き、計算し直さない
const decideUpdate = (
  stores: DishKindStores,
  { dishId, name, quantity }: Extract<DishWrite, { type: "update_dish" }>,
): WriteDecision<AddedRecordType> => {
  const current = stores.dish.find(dishId);
  if (current === undefined) {
    return rejected(dishId, "record_not_found");
  }
  if (
    !isWithinAcceptedRange("dishNameTrimmedLength", name.trim().length) ||
    (quantity !== undefined && !isAcceptableQuantity(current, quantity))
  ) {
    return rejected(dishId, "out_of_range");
  }
  const renamed = name !== current.name;
  const quantityCorrection =
    quantity !== undefined && quantity.value !== current.quantity?.value ? quantity : undefined;
  // 比例の明細の材料は、同じ料理の今の材料でないと書けない（表の外部キーでは守れない）。
  // 推定し直しで材料が置き換わっていたときの ingredients_replaced は、推定し直しのチケットで足す。それまでは範囲の外とする
  if (
    quantityCorrection !== undefined &&
    !isSameIdSet(
      quantityCorrection.proportionedIngredients.map(({ ingredientId }) => ingredientId),
      stores.ingredient.findCurrentIdsOfDish(dishId),
    )
  ) {
    return rejected(dishId, "out_of_range");
  }
  if (!renamed && quantityCorrection === undefined) {
    return {
      writeKind: "update",
      recordId: dishId,
      outcome: { result: "applied" },
      changedRecordId: undefined,
      addedChanges: [],
      usageEvents: [],
      commit: () => undefined,
    };
  }
  return {
    writeKind: "update",
    recordId: dishId,
    outcome: { result: "applied" },
    changedRecordId: dishId,
    addedChanges: (quantityCorrection?.proportionedIngredients ?? []).map(({ ingredientId }) => ({
      recordType: "ingredient",
      recordId: ingredientId,
    })),
    // 比例させた材料は、使う人が直した量でないので送らない。直してある量をもう一度直したときも送らない
    usageEvents:
      quantityCorrection !== undefined && current.quantity?.source === "estimated"
        ? [
            {
              name: "estimated_quantity_corrected",
              target: "dish",
              mealInput: "photo",
              ingredientNutrientSource: undefined,
              ratio: quantityCorrection.value / current.quantity.value,
            },
          ]
        : [],
    commit: (receiptId) => {
      if (renamed) {
        stores.dish.insertNameCorrection(receiptId, name);
      }
      if (quantityCorrection !== undefined) {
        stores.dish.insertQuantityCorrection(receiptId, quantityCorrection);
      }
    },
  };
};

// 量を持つ当てた推定が無い料理（単位が一度も無い料理）は、量を直せない
const isAcceptableQuantity = (current: Dish, quantity: DishQuantityCorrection): boolean =>
  current.quantity !== undefined &&
  isWithinAcceptedRange("dishQuantity", quantity.value) &&
  quantity.proportionedIngredients.every((ingredient) =>
    isWithinAcceptedRange("ingredientQuantity", ingredient.quantity),
  );

const isSameIdSet = (left: readonly string[], right: readonly string[]): boolean => {
  const rightSet = new Set(right);
  return (
    new Set(left).size === left.length &&
    left.length === rightSet.size &&
    left.every((id) => rightSet.has(id))
  );
};

const rejected = (dishId: string, reason: RejectionReason): WriteDecision<AddedRecordType> => ({
  writeKind: "update",
  recordId: dishId,
  outcome: { result: "rejected", reason },
  changedRecordId: undefined,
  addedChanges: [],
  usageEvents: [],
  commit: () => undefined,
});
