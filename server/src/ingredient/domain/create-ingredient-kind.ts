import { match } from "ts-pattern";
import type { RecordId } from "../../domain/record-id";
import { isWithinAcceptedRange } from "../../domain/is-within-accepted-range";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import { rejectWrite } from "../../domain/sync-ledger/reject-write";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import { computeReestimatedDishEditedEvents } from "../../dish/domain/compute-reestimated-dish-edited-events";
import { dishAwaitsEstimation } from "../../dish/domain/dish-awaits-estimation";
import type { DishStore } from "../../dish/domain/dish-store";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { MealEstimationStatusStore } from "../../meal-estimation-status/domain/meal-estimation-status-store";
import type { Ingredient } from "./ingredient";
import type { IngredientStore } from "./ingredient-store";
import { type IngredientWrite, ingredientWriteTypes } from "./ingredient-write";

// 材料の種類。サーバーが推定の完了で作り、端末が量を直す。消えるのは料理・食事を消す書き込みで
export const createIngredientKind = (
  stores: IngredientKindStores,
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

type IngredientKindStores = {
  ingredient: IngredientStore;
  dish: DishStore;
  dishEstimationStatus: DishEstimationStatusStore;
  mealEstimationStatus: MealEstimationStatusStore;
};

// 直した量は修正の出来事として足す。今の量と同じなら何も足さない。
// 前の推定の材料（推定し直しで置き換わった材料）は、今の値が削除の印でも ingredients_replaced にし、
// 料理ごと消えていた材料（削除の印がある）と分ける（端末は「直せなかった」行を出す）。
// 材料の料理の食事が推定を待っているか、材料の料理が推定し直しを待っていれば断る。
// 置き換わった材料は待っても直せないので、それより先に確かめる
const decideUpdate = (
  stores: IngredientKindStores,
  ingredientId: RecordId,
  quantity: number,
  receivedAt: Date,
): WriteDecision<AddedRecordType> => {
  const store = stores.ingredient;
  const current = store.find(ingredientId);
  if (current === undefined) {
    return rejectWrite(
      "update",
      ingredientId,
      store.isReplaced(ingredientId) ? "ingredients_replaced" : "record_not_found",
    );
  }
  const dish = stores.dish.find(current.dishId);
  if (dish === undefined) {
    throw new Error(`材料の料理が無い: ${current.dishId}`);
  }
  if (dishAwaitsEstimation(stores, dish, receivedAt)) {
    return rejectWrite("update", ingredientId, "awaiting_estimation");
  }
  if (!isWithinAcceptedRange("ingredientQuantity", quantity)) {
    return rejectWrite("update", ingredientId, "out_of_range");
  }
  if (quantity === current.quantity) {
    return { result: "unchanged", writeKind: "update", recordId: ingredientId };
  }
  return {
    result: "applied",
    writeKind: "update",
    recordId: ingredientId,
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
