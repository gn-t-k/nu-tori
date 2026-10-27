import type { RecordId } from "../../domain/record-id";
import type { DishStore } from "../../dish/domain/dish-store";
import { createDishEstimationStatusKind } from "../../dish-estimation-status/domain/create-dish-estimation-status-kind";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import type { MealStore } from "../../meal/domain/meal-store";
import { createMealEstimationStatusKind } from "../../meal-estimation-status/domain/create-meal-estimation-status-kind";
import type { MealEstimationStatusStore } from "../../meal-estimation-status/domain/meal-estimation-status-store";
import { computeEstimationEndedEvent } from "./compute-estimation-ended-event";
import type { EstimationEventWriteStore } from "./estimation-event-write-store";
import type { EstimationScheduleStore } from "./estimation-schedule-store";
import type { EstimationStore } from "./estimation-store";
import type { EstimationTarget } from "./estimation-target";
import type { EstimationWrites } from "./estimation-writes";

// 推定の書き込みを開く。書いた食事・料理ごとに、初めて書く前の推定の状態を、食事の推定の状態・料理ごとの推定の状態の種類で覚える。
// addStatusChanges は、書き終えたあとに1回呼ぶ。覚えた状態と今の状態を比べ、違う記録にだけ、書いた順に推定の状態の変更を足す。
// 推定の状態は出来事だけで決まる（compute-estimation-status）ので、比べれば変わった記録が分かる。
// 推定を終える書き込み（完了・断念）は、書いた推定の出来事を返す（compute-estimation-ended-event.ts）
export const openEstimationEventWrites = (
  stores: {
    meal: MealStore;
    mealEstimationStatus: MealEstimationStatusStore;
    dish: DishStore;
    dishEstimationStatus: DishEstimationStatusStore;
    estimationEventWrite: EstimationEventWriteStore;
    estimation: EstimationStore;
    estimationSchedule: EstimationScheduleStore;
  },
  addChange: (
    change: RecordChangeTarget<"meal_estimation_status" | "dish_estimation_status">,
  ) => void,
): { writes: EstimationWrites; addStatusChanges: () => void } => {
  const mealStatusKind = createMealEstimationStatusKind(stores.meal, stores.mealEstimationStatus);
  const dishStatusKind = createDishEstimationStatusKind(stores.dish, stores.dishEstimationStatus);
  const store = stores.estimationEventWrite;
  // 書いた順を保つため、食事と料理を1つの並びで覚える
  const statusesBeforeWrites = new Map<
    string,
    {
      change: RecordChangeTarget<"meal_estimation_status" | "dish_estimation_status">;
      before: CurrentRecord<string>;
    }
  >();
  const rememberMeal = (mealId: RecordId) => {
    const key = `meal:${mealId}`;
    if (!statusesBeforeWrites.has(key)) {
      statusesBeforeWrites.set(key, {
        change: { recordType: "meal_estimation_status", recordId: mealId },
        before: mealStatusKind.readCurrent(mealId),
      });
    }
  };
  const rememberDish = (dishId: RecordId) => {
    const key = `dish:${dishId}`;
    if (!statusesBeforeWrites.has(key)) {
      statusesBeforeWrites.set(key, {
        change: { recordType: "dish_estimation_status", recordId: dishId },
        before: dishStatusKind.readCurrent(dishId),
      });
    }
  };
  const rememberTarget = (target: EstimationTarget) => {
    if (target.type === "meal") {
      rememberMeal(target.mealId);
      return;
    }
    rememberDish(target.dishId);
  };

  const writes: EstimationWrites = {
    scheduleMeal: (schedule) => {
      rememberMeal(schedule.mealId);
      store.insertMealSchedule(schedule);
    },
    scheduleDish: (schedule) => {
      rememberDish(schedule.dishId);
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
    hold: ({ target, ...hold }) => {
      rememberTarget(target);
      store.insertHold(hold);
    },
    beginEstimation: ({ target, ...estimation }) => {
      rememberTarget(target);
      store.insertEstimation(estimation);
    },
    beginAttempt: (attempt) => {
      store.insertAttempt(attempt);
    },
    recordAttemptResult: (attemptResult) => {
      store.insertAttemptResult(attemptResult);
    },
    complete: ({ target, dishCount, ingredients, ...completion }) => {
      rememberTarget(target);
      const result = dishCount === 0 ? "no_dishes" : "estimated";
      store.insertCompletion({ ...completion, result });
      return computeEstimationEndedEvent(stores, {
        estimationId: completion.estimationId,
        target,
        finalStatus: result,
        endedAt: completion.completedAt,
        dishCount,
        ingredients,
      });
    },
    abandon: ({ target, ...abandonment }) => {
      rememberTarget(target);
      store.insertAbandonment(abandonment);
      return computeEstimationEndedEvent(stores, {
        estimationId: abandonment.estimationId,
        target,
        finalStatus: "failed",
        endedAt: abandonment.abandonedAt,
        dishCount: 0,
        ingredients: [],
      });
    },
    estimateMealEatenAt: (estimation) => {
      store.insertMealEatenAtEstimation(estimation);
    },
    recordCreatedMeal: (createdMeal) => {
      rememberMeal(createdMeal.mealId);
      store.insertCreatedMeal(createdMeal);
    },
  };

  const addStatusChanges = (): void => {
    for (const { change, before } of statusesBeforeWrites.values()) {
      const after =
        change.recordType === "meal_estimation_status"
          ? mealStatusKind.readCurrent(change.recordId)
          : dishStatusKind.readCurrent(change.recordId);
      if (!isSameStatus(before, after)) {
        addChange(change);
      }
    }
  };
  return { writes, addStatusChanges };
};

const isSameStatus = (a: CurrentRecord<string>, b: CurrentRecord<string>): boolean =>
  a.status === "value" && b.status === "value" ? a.value === b.value : a.status === b.status;
