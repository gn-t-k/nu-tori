import { match } from "ts-pattern";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import { isWithinAcceptedRange } from "../../domain/is-within-accepted-range";
import type { RejectionReason } from "../../domain/rejection-reason";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import type { Meal } from "./meal";
import { isMealEntryMethod } from "./meal-entry-method";
import type { MealStore } from "./meal-store";
import { type MealWrite, mealWriteTypes } from "./meal-write";

export const createMealKind = (
  store: MealStore,
): RecordKind<"meal", MealWrite, Meal, "meal_estimation_status"> => ({
  name: "meal",
  writes: {
    isWrite: (write): write is MealWrite => mealWriteTypes.includes(write.type),
    decide: (write) =>
      match(write)
        .with({ type: "create_meal" }, ({ meal }) => decideCreate(store, meal))
        .with({ type: "delete_meal" }, ({ mealId }) => decideDelete(store, mealId))
        .exhaustive(),
  },
  readCurrent: (recordId): CurrentRecord<Meal> => {
    const meal = store.find(recordId);
    if (meal !== undefined) {
      return { status: "value", value: meal };
    }
    return store.hasDeletion(recordId) ? { status: "deleted" } : { status: "absent" };
  },
});

type NewMeal = Extract<MealWrite, { type: "create_meal" }>["meal"];

const decideCreate = (
  store: MealStore,
  newMeal: NewMeal,
): WriteDecision<"meal_estimation_status"> => {
  const { entryMethod, photoIds } = newMeal;
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
      commit: () => undefined,
    };
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
    commit: () => {
      store.insert(meal);
    },
  };
};

// 食事を書かずに終わる。この写真の ID は、もう食事に付かない印を書く（先に届いていた写真は消し残しになり、あとから届いた写真は置かない）。
// ほかの食事の写真と、もう印のある写真には書かない。削除の印で捨てたときだけ、変更の並びに載せる
const discarded = (
  store: MealStore,
  newMeal: NewMeal,
  outcome: { result: "ignored_tombstone" } | { result: "rejected"; reason: RejectionReason },
): WriteDecision<"meal_estimation_status"> => {
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
    commit: (receiptId) => {
      store.insertPhotoDeletions(unusedPhotoIds, receiptId);
    },
  };
};

const decideDelete = (
  store: MealStore,
  mealId: string,
): WriteDecision<"meal_estimation_status"> => {
  if (store.hasDeletion(mealId)) {
    return {
      writeKind: "delete",
      recordId: mealId,
      outcome: { result: "ignored_tombstone" },
      changedRecordId: mealId,
      addedChanges: [],
      commit: () => undefined,
    };
  }
  const meal = store.find(mealId);
  // 食事がまだ届いていなくても印を残し、同じ要求やあとから届く作る書き込みで生き返らせない
  return {
    writeKind: "delete",
    recordId: mealId,
    outcome: { result: "applied" },
    changedRecordId: mealId,
    addedChanges: [{ recordType: "meal_estimation_status", recordId: mealId }],
    commit: (receiptId) => {
      if (meal !== undefined) {
        store.remove(mealId);
        store.insertPhotoDeletions(meal.photoIds, receiptId);
      }
      store.insertDeletion(receiptId);
    },
  };
};
