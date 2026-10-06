import { match } from "ts-pattern";
import { isWithinAcceptedRange } from "../../domain/is-within-accepted-range";
import type { RejectionReason } from "../../domain/rejection-reason";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import { decideWithoutChange } from "../../domain/sync-ledger/decide-without-change";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import { computeReestimatedDishEditedEvents } from "../../dish/domain/compute-reestimated-dish-edited-events";
import type { DishStore } from "../../dish/domain/dish-store";
import type { Ingredient } from "./ingredient";
import type { IngredientStore } from "./ingredient-store";
import { type IngredientWrite, ingredientWriteTypes } from "./ingredient-write";

// 材料の種類。サーバーが推定の完了で作り、端末が量を直す。消えるのは料理・食事を消す書き込みで
export const createIngredientKind = (
  stores: { ingredient: IngredientStore; dish: DishStore },
  receivedAt: Date,
): RecordKind<"ingredient", IngredientWrite, Ingredient, AddedRecordType> => ({
  name: "ingredient",
  writes: {
    isWrite: (write): write is IngredientWrite => ingredientWriteTypes.includes(write.type),
    decide: (write) =>
      match(write)
        .with({ type: "update_ingredient" }, ({ ingredientId, quantity }) =>
          decideUpdate(stores, ingredientId, quantity, receivedAt),
        )
        .exhaustive(),
  },
  follows: undefined,
  whenGone: "deletion_mark",
  readCurrent: (ingredientId): CurrentRecord<Ingredient> => {
    const ingredient = stores.ingredient.find(ingredientId);
    if (ingredient !== undefined) {
      return { status: "value", value: ingredient };
    }
    return stores.ingredient.hasDeletion(ingredientId)
      ? { status: "deleted" }
      : { status: "absent" };
  },
});

// 材料の量を直すと料理の版が上がるので、料理の変更も足す
type AddedRecordType = "dish";

// 直した量は修正の出来事として足す。今の量と同じなら何も足さない。
// 前の推定の材料（推定し直しで置き換わった材料）は、今の値が削除の印でも ingredients_replaced にし、
// 料理ごと消えていた材料（削除の印がある）と分ける（端末は「直せなかった」行を出す）
const decideUpdate = (
  stores: { ingredient: IngredientStore; dish: DishStore },
  ingredientId: string,
  quantity: number,
  receivedAt: Date,
): WriteDecision<AddedRecordType> => {
  const store = stores.ingredient;
  const current = store.find(ingredientId);
  if (current === undefined) {
    return rejected(
      ingredientId,
      store.isReplaced(ingredientId) ? "ingredients_replaced" : "record_not_found",
    );
  }
  if (!isWithinAcceptedRange("ingredientQuantity", quantity)) {
    return rejected(ingredientId, "out_of_range");
  }
  if (quantity === current.quantity) {
    return decideWithoutChange("update", ingredientId, { result: "applied" });
  }
  return {
    writeKind: "update",
    recordId: ingredientId,
    outcome: { result: "applied" },
    changedRecordId: ingredientId,
    addedChanges: [{ recordType: "dish", recordId: current.dishId }],
    // 直してある量をもう一度直したときは、推定の量を直した率にならないので送らない
    usageEvents: [
      ...(current.quantitySource === "estimated"
        ? [
            {
              name: "estimated_quantity_corrected" as const,
              target: "ingredient" as const,
              mealInput: "photo" as const,
              ingredientNutrientSource: current.nutrientSource.type,
              ratio: quantity / current.quantity,
            },
          ]
        : []),
      // 材料を直すのも、その料理をまた直したことに数える
      ...computeReestimatedDishEditedEvents(stores.dish, current.dishId, "corrected", receivedAt),
    ],
    commit: (receiptId) => {
      store.insertQuantityCorrection(receiptId, quantity);
    },
  };
};

const rejected = (ingredientId: string, reason: RejectionReason): WriteDecision<AddedRecordType> =>
  decideWithoutChange("update", ingredientId, { result: "rejected", reason });
