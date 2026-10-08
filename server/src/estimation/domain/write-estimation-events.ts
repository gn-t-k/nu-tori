import type { RecordId } from "../../domain/record-id";
import type { DishStore } from "../../dish/domain/dish-store";
import { createDishEstimationStatusKind } from "../../dish-estimation-status/domain/create-dish-estimation-status-kind";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import type { MealStore } from "../../meal/domain/meal-store";
import { createMealEstimationStatusKind } from "../../meal-estimation-status/domain/create-meal-estimation-status-kind";
import type { MealEstimationStatusStore } from "../../meal-estimation-status/domain/meal-estimation-status-store";
import type { EstimationEventWriteStore } from "./estimation-event-write-store";
import type { EstimationTarget } from "./estimation-target";
import type { EstimationWrites } from "./estimation-writes";

// 推定の書き込みの口。推定の予定と結果は、ここを通して書く。
// 書いた食事・料理ごとに、初めて書く前と run のあとの推定の状態を、食事の推定の状態・料理ごとの推定の状態の種類で出し、
// 違う記録にだけ、書いた順に推定の状態の変更を足す。addChange は帳簿の changeOutsideWrites か、書き込みの決定の commit に渡るもの。
// 料理の推定を始めたときは、状態が同じでも変更を足す: 見送りから作った次の日の予定は、0:00 を過ぎると出来事が無いまま
// 翌日に推定から推定中に変わるので、比べると変わっておらず、端末に届かないため（#332 の「料理ごとの推定の状態の出し方」）。
// now は料理ごとの推定の状態を決める時刻
export const writeEstimationEvents = <T>(
  stores: {
    meal: MealStore;
    mealEstimationStatus: MealEstimationStatusStore;
    dish: DishStore;
    dishEstimationStatus: DishEstimationStatusStore;
    estimationEventWrite: EstimationEventWriteStore;
  },
  addChange: (
    change: RecordChangeTarget<"meal_estimation_status" | "dish_estimation_status">,
  ) => void,
  now: Date,
  run: (writes: EstimationWrites) => T,
): T => {
  const mealStatusKind = createMealEstimationStatusKind(stores.meal, stores.mealEstimationStatus);
  const dishStatusKind = createDishEstimationStatusKind(
    stores.dish,
    stores.dishEstimationStatus,
    now,
  );
  const store = stores.estimationEventWrite;
  // 書いた順を保つため、食事と料理を1つの並びで覚える
  const statusesBeforeWrites = new Map<
    string,
    {
      change: RecordChangeTarget<"meal_estimation_status" | "dish_estimation_status">;
      before: CurrentRecord<string>;
      always: boolean;
    }
  >();
  const rememberMeal = (mealId: RecordId) => {
    const key = `meal:${mealId}`;
    if (!statusesBeforeWrites.has(key)) {
      statusesBeforeWrites.set(key, {
        change: { recordType: "meal_estimation_status", recordId: mealId },
        before: mealStatusKind.readCurrent(mealId),
        always: false,
      });
    }
  };
  // always は、状態が同じでも変更を足すか（料理の推定を始めたとき）
  const rememberDish = (dishId: RecordId, { always }: { always: boolean }) => {
    const key = `dish:${dishId}`;
    const remembered = statusesBeforeWrites.get(key);
    if (remembered === undefined) {
      statusesBeforeWrites.set(key, {
        change: { recordType: "dish_estimation_status", recordId: dishId },
        before: dishStatusKind.readCurrent(dishId),
        always,
      });
      return;
    }
    // 同じ run で先に覚えた料理の推定を始めたときも、変更を足す
    remembered.always ||= always;
  };
  const rememberTarget = (target: EstimationTarget) => {
    if (target.type === "meal") {
      rememberMeal(target.mealId);
      return;
    }
    rememberDish(target.dishId, { always: false });
  };

  const result = run({
    scheduleMeal: (schedule) => {
      rememberMeal(schedule.mealId);
      store.insertMealSchedule(schedule);
    },
    scheduleDish: (schedule) => {
      rememberDish(schedule.dishId, { always: false });
      store.insertDishSchedule(schedule);
    },
    deferToNextDay: ({ scheduleId, target, deferredAt, nextSchedule }) => {
      rememberTarget(target);
      store.insertDeferral({ scheduleId, deferredAt });
      if (target.type === "meal") {
        store.insertMealSchedule({ ...nextSchedule, mealId: target.mealId });
        return;
      }
      store.insertDishSchedule({ ...nextSchedule, dishId: target.dishId });
    },
    beginEstimation: ({ target, ...estimation }) => {
      if (target.type === "meal") {
        rememberMeal(target.mealId);
      } else {
        rememberDish(target.dishId, { always: true });
      }
      store.insertEstimation(estimation);
    },
    beginAttempt: (attempt) => {
      store.insertAttempt(attempt);
    },
    recordAttemptResult: (attemptResult) => {
      store.insertAttemptResult(attemptResult);
    },
    complete: ({ target, ...completion }) => {
      rememberTarget(target);
      store.insertCompletion(completion);
    },
    abandon: ({ target, ...abandonment }) => {
      rememberTarget(target);
      store.insertAbandonment(abandonment);
    },
  });

  for (const { change, before, always } of statusesBeforeWrites.values()) {
    const after =
      change.recordType === "meal_estimation_status"
        ? mealStatusKind.readCurrent(change.recordId)
        : dishStatusKind.readCurrent(change.recordId);
    if (always || !isSameStatus(before, after)) {
      addChange(change);
    }
  }
  return result;
};

const isSameStatus = (a: CurrentRecord<string>, b: CurrentRecord<string>): boolean =>
  a.status === "value" && b.status === "value" ? a.value === b.value : a.status === b.status;
