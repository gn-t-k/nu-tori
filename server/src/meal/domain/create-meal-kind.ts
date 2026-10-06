import { match } from "ts-pattern";
import { deleteDishes } from "../../dish/domain/delete-dishes";
import type { DishStore } from "../../dish/domain/dish-store";
import { computeEstimationEndedEvent } from "../../estimation/domain/compute-estimation-ended-event";
import type { EstimationStore } from "../../estimation/domain/estimation-store";
import { findMealReceivedAt } from "../../estimation/domain/find-meal-received-at";
import { scheduleMealEstimation } from "../../estimation/domain/schedule-meal-estimation";
import type { EstimationScheduleStore } from "../../estimation/domain/estimation-schedule-store";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { LatestTimeZoneStore } from "../../domain/latest-time-zone-store";
import { computeCalendarDay } from "../../domain/compute-calendar-day";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import { isWithinAcceptedRange } from "../../domain/is-within-accepted-range";
import type { RejectionReason } from "../../domain/rejection-reason";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import type { UsageEvent } from "../../domain/usage-event";
import type { IngredientStore } from "../../ingredient/domain/ingredient-store";
import type { Meal } from "./meal";
import { isMealEntryMethod } from "./meal-entry-method";
import type { MealPhotoStore } from "./meal-photo-store";
import type { MealStore } from "./meal-store";
import { type MealWrite, mealWriteTypes } from "./meal-write";

// receivedAt は要求を受け取った時刻。写真がそろった食事の推定の予定の時刻と、数える日に使う
export const createMealKind = (
  stores: MealKindStores,
  receivedAt: Date,
): RecordKind<"meal", MealWrite, Meal, AddedRecordType> => ({
  name: "meal",
  writes: {
    isWrite: (write): write is MealWrite => mealWriteTypes.includes(write.type),
    decide: (write) =>
      match(write)
        .with({ type: "create_meal" }, ({ meal }) => decideCreate(stores, meal, receivedAt))
        .with({ type: "delete_meal" }, ({ mealId }) => decideDelete(stores, mealId, receivedAt))
        .with({ type: "update_meal" }, ({ mealId, eatenAt }) =>
          decideUpdate(stores, mealId, eatenAt),
        )
        .exhaustive(),
  },
  follows: undefined,
  whenGone: "deletion_mark",
  readCurrent: (recordId): CurrentRecord<Meal> => {
    const meal = stores.meal.find(recordId);
    if (meal !== undefined) {
      return { status: "value", value: meal };
    }
    return stores.meal.hasDeletion(recordId) ? { status: "deleted" } : { status: "absent" };
  },
});

// 食事の書き込みが、食事のほかに変える記録の種類
type AddedRecordType = "meal_estimation_status" | "dish" | "ingredient";

// 食事の書き込みが読み書きする置き場
type MealKindStores = {
  meal: MealStore;
  mealPhoto: MealPhotoStore;
  estimationSchedule: EstimationScheduleStore;
  latestTimeZone: LatestTimeZoneStore;
  estimation: EstimationStore;
  writeEstimationEvents: RecordKindStores["writeEstimationEvents"];
  dish: DishStore;
  ingredient: IngredientStore;
};

type NewMeal = Extract<MealWrite, { type: "create_meal" }>["meal"];

const decideCreate = (
  stores: MealKindStores,
  newMeal: NewMeal,
  receivedAt: Date,
): WriteDecision<AddedRecordType> => {
  const store = stores.meal;
  const { entryMethod, photoIds } = newMeal;
  if (store.hasDeletion(newMeal.id)) {
    return discarded(store, newMeal, { result: "ignored_tombstone" });
  }
  // 写真はいまの食事のものなので、写真の削除の印を書かない
  if (store.find(newMeal.id) !== undefined) {
    return {
      writeKind: "create",
      recordId: newMeal.id,
      outcome: { result: "ignored_duplicate" },
      changedRecordId: undefined,
      addedChanges: [],
      usageEvents: [],
      commit: () => undefined,
    };
  }
  if (
    !isWithinAcceptedRange("mealPhotoCount", photoIds.length) ||
    !isWithinAcceptedRange("mealUtcOffsetSeconds", newMeal.eatenAtUtcOffsetSeconds)
  ) {
    return discarded(store, newMeal, { result: "rejected", reason: "out_of_range" });
  }
  if (new Set(photoIds).size !== photoIds.length) {
    return discarded(store, newMeal, { result: "rejected", reason: "duplicate_photo_ids" });
  }
  if (!isMealEntryMethod(entryMethod)) {
    return discarded(store, newMeal, { result: "rejected", reason: "invalid_entry_method" });
  }
  if (!isTimeZoneName(newMeal.sentTimeZone)) {
    return discarded(store, newMeal, { result: "rejected", reason: "invalid_time_zone" });
  }
  // 写真の宣言の一意の違反で要求ごと戻ると、送り直し続けるので、書く前に確かめる
  if (store.findUsedPhotoIds(photoIds).length > 0) {
    return discarded(store, newMeal, { result: "rejected", reason: "photo_already_used" });
  }
  const meal: Meal = { ...newMeal, entryMethod };
  return {
    writeKind: "create",
    recordId: meal.id,
    outcome: { result: "applied" },
    changedRecordId: meal.id,
    addedChanges: [{ recordType: "meal_estimation_status", recordId: meal.id }],
    usageEvents: [
      {
        name: "meal_received",
        entryMethod,
        minutesFromEatenToSent: Math.round(
          (meal.sentAt.getTime() - meal.eatenAt.getTime()) / 60_000,
        ),
        mealCountOfDay: countMealsOnEatenDay(store, meal) + 1,
      },
    ],
    commit: () => {
      store.insert(meal);
      stores.writeEstimationEvents(discardStatusChangeAddedWithMeal, (writes) =>
        scheduleMealEstimation(stores, writes, meal, receivedAt),
      );
    },
  };
};

// 推定の状態の変更は、食事ができたことに付いて addedChanges で1つ足す。写真がそろって予定に入れても1つでよいので、
// 推定の書き込みの口が足す変更は捨てる
const discardStatusChangeAddedWithMeal = (): void => undefined;

// 食べた日の、いまある食事の数。消した食事は行が無いので数えない
const countMealsOnEatenDay = (store: MealStore, meal: Meal): number => {
  const eatenDay = computeCalendarDay(meal.eatenAt, meal.eatenAtUtcOffsetSeconds);
  const dayLengthMs = 86_400_000;
  // 時差の範囲は1日より狭いので、UTC でその日の前後1日を引けば、食べた日がその日の食事は漏れない
  const startOfDayInUtc = Date.parse(`${eatenDay}T00:00:00Z`);
  return store
    .findEatenTimesBetween(
      new Date(startOfDayInUtc - dayLengthMs),
      new Date(startOfDayInUtc + 2 * dayLengthMs),
    )
    .filter(
      ({ eatenAt, eatenAtUtcOffsetSeconds }) =>
        computeCalendarDay(eatenAt, eatenAtUtcOffsetSeconds) === eatenDay,
    ).length;
};

// 食事を書かずに終わる。写真の削除の印は、先に届いた写真を消し残しにし、あとから届く写真を置かせないために、まだ宣言にも印にも無い ID にだけ書く
const discarded = (
  store: MealStore,
  newMeal: NewMeal,
  outcome: { result: "ignored_tombstone" } | { result: "rejected"; reason: RejectionReason },
): WriteDecision<AddedRecordType> => {
  const usedPhotoIds = store.findUsedPhotoIds(newMeal.photoIds);
  const unusedPhotoIds = [...new Set(newMeal.photoIds)].filter(
    (photoId) => !usedPhotoIds.includes(photoId),
  );
  return {
    writeKind: "create",
    recordId: newMeal.id,
    outcome,
    changedRecordId: outcome.result === "ignored_tombstone" ? newMeal.id : undefined,
    addedChanges: [],
    usageEvents: [],
    commit: (receiptId) => {
      store.insertPhotoDeletions(unusedPhotoIds, receiptId);
    },
  };
};

// 料理・材料・写真の宣言を消し、それぞれの削除の印を残す。料理と材料の変更は1つずつ足す。
// 推定中の食事なら、つなぎが CASCADE で消える前に推定を読み、推定ごとの出来事を「食事が消えた」で送る
const decideDelete = (
  stores: MealKindStores,
  mealId: string,
  receivedAt: Date,
): WriteDecision<AddedRecordType> => {
  const store = stores.meal;
  if (store.hasDeletion(mealId)) {
    return {
      writeKind: "delete",
      recordId: mealId,
      outcome: { result: "ignored_tombstone" },
      changedRecordId: mealId,
      addedChanges: [],
      usageEvents: [],
      commit: () => undefined,
    };
  }
  const meal = store.find(mealId);
  const dishIds = stores.dish.findIdsOfMeal(mealId);
  const ingredientIds = stores.ingredient.findIdsOfMeal(mealId);
  // 食事がまだ届いていなくても印を残し、同じ要求やあとから届く作る書き込みで生き返らせない
  return {
    writeKind: "delete",
    recordId: mealId,
    outcome: { result: "applied" },
    changedRecordId: mealId,
    addedChanges: [
      { recordType: "meal_estimation_status", recordId: mealId },
      ...dishIds.map((recordId) => ({ recordType: "dish" as const, recordId })),
      ...ingredientIds.map((recordId) => ({ recordType: "ingredient" as const, recordId })),
    ],
    usageEvents: computeMealDeletedEstimationEvents(stores, mealId, receivedAt),
    // #332 の「消す順」: 料理ごとの中身を消してから、食事の時刻の修正を消し、食事の削除の印を書いて食事を消す
    commit: (receiptId) => {
      deleteDishes(stores, { dishIds, ingredientIds }, receiptId);
      store.removeCorrections(mealId);
      store.insertDeletion(receiptId);
      if (meal !== undefined) {
        store.insertPhotoDeletions(meal.photoIds, receiptId);
        store.remove(mealId);
      }
    },
  };
};

// 撮った時刻を直す。時刻を確かめない（#188 の作る書き込みと同じ）。時刻の修正はその食事の料理すべての版を上げるので、料理の変更も足す。
// 修正の行の順は変更の並びの通し番号で決まるので、修正を書くときは必ず食事を changedRecordId に返す
const decideUpdate = (
  stores: MealKindStores,
  mealId: string,
  eatenAt: Date,
): WriteDecision<AddedRecordType> => {
  const store = stores.meal;
  const meal = store.find(mealId);
  if (meal === undefined) {
    return {
      writeKind: "update",
      recordId: mealId,
      outcome: { result: "rejected", reason: "record_not_found" },
      changedRecordId: undefined,
      addedChanges: [],
      usageEvents: [],
      commit: () => undefined,
    };
  }
  if (meal.eatenAt.getTime() === eatenAt.getTime()) {
    return {
      writeKind: "update",
      recordId: mealId,
      outcome: { result: "applied" },
      changedRecordId: undefined,
      addedChanges: [],
      usageEvents: [],
      commit: () => undefined,
    };
  }
  return {
    writeKind: "update",
    recordId: mealId,
    outcome: { result: "applied" },
    changedRecordId: mealId,
    addedChanges: stores.dish
      .findIdsOfMeal(mealId)
      .map((recordId) => ({ recordType: "dish" as const, recordId })),
    usageEvents: [],
    commit: (receiptId) => {
      store.insertEatenAtCorrection(eatenAt, receiptId);
    },
  };
};

const computeMealDeletedEstimationEvents = (
  stores: MealKindStores,
  mealId: string,
  deletedAt: Date,
): UsageEvent[] => {
  const estimationId = stores.estimation.findOngoingEstimationIdOfMeal(mealId);
  if (estimationId === undefined) {
    return [];
  }
  return [
    computeEstimationEndedEvent({
      finalStatus: "meal_deleted",
      attempts: stores.estimation.findAttempts(estimationId),
      receivedAt: findMealReceivedAt(stores.estimationSchedule, mealId),
      endedAt: deletedAt,
      dishCount: 0,
      ingredients: [],
    }),
  ];
};
