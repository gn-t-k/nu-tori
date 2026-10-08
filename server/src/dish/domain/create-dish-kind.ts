import { match } from "ts-pattern";
import type { RecordId } from "../../domain/record-id";
import { isWithinAcceptedRange } from "../../domain/is-within-accepted-range";
import { mealAwaitsEstimation } from "../../meal-estimation-status/domain/meal-awaits-estimation";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import { rejectWrite } from "../../domain/sync-ledger/reject-write";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import { computeDishDeletedEstimationEvents } from "../../estimation/domain/compute-dish-deleted-estimation-events";
import { scheduleDishReestimation } from "../../estimation/domain/schedule-dish-reestimation";
import { computeReestimatedDishEditedEvents } from "./compute-reestimated-dish-edited-events";
import { dishAwaitsEstimation } from "./dish-awaits-estimation";
import { deleteDishes } from "./delete-dishes";
import type { Dish } from "./dish";
import { type DishQuantityCorrection, type DishWrite, dishWriteTypes } from "./dish-write";

// 料理の種類。サーバーが推定の完了で作り、端末が足し、名前と量を直し、消す。足したときと名前を直したときは、サーバーがその料理だけを推定し直す。
// receivedAt は要求を受け取った時刻。推定し直しの予定の時刻と数える日に使う
export const createDishKind = (
  stores: DishKindStores,
  receivedAt: Date,
): RecordKind<"dish", DishWrite, Dish, AddedRecordType> => ({
  name: "dish",
  writes: {
    isWrite: (write): write is DishWrite => dishWriteTypes.includes(write.type),
    decide: (write) =>
      match(write)
        .with({ type: "create_dish" }, (create) => decideCreate(stores, create, receivedAt))
        .with({ type: "delete_dish" }, ({ dishId }) => decideDelete(stores, dishId, receivedAt))
        .with({ type: "update_dish" }, (update) => decideUpdate(stores, update, receivedAt))
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

// 料理の書き込みが、料理のほかに変える記録の種類。食事の推定の状態は、推定の書き込みの口が足しうるので含める
type AddedRecordType = "ingredient" | "dish_estimation_status" | "meal_estimation_status";

type DishKindStores = Pick<
  RecordKindStores,
  | "dish"
  | "dishEstimationStatus"
  | "ingredient"
  | "meal"
  | "mealEstimationStatus"
  | "latestTimeZone"
  | "estimationSchedule"
  | "estimation"
  | "writeEstimationEvents"
>;

// 名前だけで料理を作り、名前を直したときと同じく推定し直しを予定に入れる。量と材料は推定し直しで入る。
// 足したのが使う人かは、この書き込みの控えで分かるので、料理に作り手を持たない
const decideCreate = (
  stores: DishKindStores,
  { dishId, mealId, name, positionInMeal }: Extract<DishWrite, { type: "create_dish" }>,
  receivedAt: Date,
): WriteDecision<AddedRecordType> => {
  if (stores.dish.exists(dishId)) {
    return { result: "ignored_duplicate", writeKind: "create", recordId: dishId };
  }
  if (stores.dish.hasDeletion(dishId)) {
    return { result: "ignored_tombstone", writeKind: "create", recordId: dishId };
  }
  // 消えた食事に足した料理は、削除の印を残して、あとから同じ ID が届いても生き返らせない
  if (stores.meal.hasDeletion(mealId)) {
    return {
      result: "ignored_tombstone",
      writeKind: "create",
      recordId: dishId,
      commit: (receiptId) => {
        stores.dish.insertDeletions([dishId], receiptId);
      },
    };
  }
  const meal = stores.meal.find(mealId);
  if (meal === undefined) {
    return rejectWrite("create", dishId, "record_not_found");
  }
  if (mealAwaitsEstimation(stores.mealEstimationStatus, mealId)) {
    return rejectWrite("create", dishId, "awaiting_estimation");
  }
  if (!isWithinAcceptedRange("dishNameTrimmedLength", name.trim().length)) {
    return rejectWrite("create", dishId, "out_of_range");
  }
  return {
    result: "applied",
    writeKind: "create",
    recordId: dishId,
    // 足した料理の予定は、受け取った時刻が来ているので推定中になる
    addedChanges: [{ recordType: "dish_estimation_status", recordId: dishId }],
    usageEvents: [],
    commit: (_receiptId, addChange) => {
      stores.dish.insert({ id: dishId, mealId, name, positionInMeal });
      scheduleReestimation(
        stores,
        { id: dishId, mealSentTimeZone: meal.sentTimeZone },
        receivedAt,
        addChange,
      );
    },
  };
};

// 受け付けられないことが無い書き込み（docs/agents/sync.md）。料理がまだ届いていなくても印を残し、
// あとから届く作る書き込みで生き返らせない。材料の変更は、前の推定の材料も含めて1つずつ足す。
// 推定し直しの予定のある料理は、料理ごとの推定の状態の削除の印も届ける。推定し直しの推定中なら、届いた推定は捨てられる
// （つなぎが CASCADE で消える）ので、推定ごとの出来事を「料理が消えた」で送る
const decideDelete = (
  stores: DishKindStores,
  dishId: RecordId,
  receivedAt: Date,
): WriteDecision<AddedRecordType> => {
  if (stores.dish.hasDeletion(dishId)) {
    return { result: "ignored_tombstone", writeKind: "delete", recordId: dishId };
  }
  const dish = stores.dish.find(dishId);
  const ingredientIds = stores.ingredient.findIdsOfDish(dishId);
  const hasSchedule = stores.dishEstimationStatus.findSchedulesOfDish(dishId).length > 0;
  return {
    result: "applied",
    writeKind: "delete",
    recordId: dishId,
    addedChanges: [
      ...ingredientIds.map((recordId) => ({ recordType: "ingredient" as const, recordId })),
      ...(hasSchedule ? [{ recordType: "dish_estimation_status" as const, recordId: dishId }] : []),
    ],
    usageEvents:
      dish === undefined
        ? []
        : [
            ...computeDishDeletedEstimationEvents(stores, dish, "dish_deleted", receivedAt),
            ...computeReestimatedDishEditedEvents(stores.dish, dishId, "deleted", receivedAt),
          ],
    commit: (receiptId) => {
      deleteDishes(stores, { dishIds: [dishId], ingredientIds }, receiptId);
    },
  };
};

// 名前と量は、今の値と違う分だけ修正の出来事として足す。比例させた材料の量は端末が出したものを書き、計算し直さない。
// 名前が変わったら、その料理の推定し直しを予定に入れる。
// 食事が推定を待っているときと、料理が推定し直しを待っているときは断る
const decideUpdate = (
  stores: DishKindStores,
  { dishId, name, quantity }: Extract<DishWrite, { type: "update_dish" }>,
  receivedAt: Date,
): WriteDecision<AddedRecordType> => {
  const current = stores.dish.find(dishId);
  if (current === undefined) {
    return rejectWrite("update", dishId, "record_not_found");
  }
  // 比例の明細の材料は、同じ料理の今の材料でないと書けない（表の外部キーでは守れない）。
  // 組が違うのは、端末が比例させたあとに推定し直しで材料が置き換わっていたとき。量が今と同じでも、載せた組は確かめる。
  // 待っても直せないことを返すため、推定を待っていることより先に確かめる
  if (
    quantity !== undefined &&
    !isSameIdSet(
      quantity.proportionedIngredients.map(({ ingredientId }) => ingredientId),
      stores.ingredient.findCurrentIdsOfDish(dishId),
    )
  ) {
    return rejectWrite("update", dishId, "ingredients_replaced");
  }
  if (dishAwaitsEstimation(stores, current, receivedAt)) {
    return rejectWrite("update", dishId, "awaiting_estimation");
  }
  if (
    !isWithinAcceptedRange("dishNameTrimmedLength", name.trim().length) ||
    (quantity !== undefined && !isAcceptableQuantity(current, quantity))
  ) {
    return rejectWrite("update", dishId, "out_of_range");
  }
  const renamed = name !== current.name;
  const quantityCorrection =
    quantity !== undefined && quantity.value !== current.quantity?.value ? quantity : undefined;
  if (!renamed && quantityCorrection === undefined) {
    return { result: "unchanged", writeKind: "update", recordId: dishId };
  }
  return {
    result: "applied",
    writeKind: "update",
    recordId: dishId,
    addedChanges: [
      ...(quantityCorrection?.proportionedIngredients ?? []).map(({ ingredientId }) => ({
        recordType: "ingredient" as const,
        recordId: ingredientId,
      })),
      // 名前を直した予定は、受け取った時刻が来ているので推定中になる。推定し直しを待っている料理の直しは上で断るので、前から推定中のことは無い
      ...(renamed ? [{ recordType: "dish_estimation_status" as const, recordId: dishId }] : []),
    ],
    usageEvents: [
      // 比例させた材料は、使う人が直した量でないので送らない。直してある量をもう一度直したときも送らない
      ...(quantityCorrection !== undefined && current.quantity?.source === "estimated"
        ? [
            {
              name: "estimated_quantity_corrected" as const,
              target: "dish" as const,
              mealInput: "photo" as const,
              ratio: quantityCorrection.value / current.quantity.value,
            },
          ]
        : []),
      ...computeReestimatedDishEditedEvents(stores.dish, dishId, "corrected", receivedAt),
    ],
    commit: (receiptId, addChange) => {
      if (quantityCorrection !== undefined) {
        stores.dish.insertQuantityCorrection(receiptId, quantityCorrection);
      }
      if (renamed) {
        stores.dish.insertNameCorrection(receiptId, name);
        const meal = stores.meal.find(current.mealId);
        if (meal === undefined) {
          throw new Error(`料理の食事が無い: ${current.mealId}`);
        }
        scheduleReestimation(
          stores,
          { id: dishId, mealSentTimeZone: meal.sentTimeZone },
          receivedAt,
          addChange,
        );
      }
    },
  };
};

// 推定の書き込みの口が足す推定の状態の変更は、addedChanges で足した変更と同じ記録なら、帳簿が1つにまとめる
const scheduleReestimation = (
  stores: DishKindStores,
  dish: Parameters<typeof scheduleDishReestimation>[2],
  receivedAt: Date,
  addChange: (change: RecordChangeTarget<AddedRecordType>) => void,
): void => {
  stores.writeEstimationEvents(addChange, receivedAt, (writes) =>
    scheduleDishReestimation(stores, writes, dish, receivedAt),
  );
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
