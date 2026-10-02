import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import type { MealStore } from "../../meal/domain/meal-store";
import { createMealEstimationStatusKind } from "../../meal-estimation-status/domain/create-meal-estimation-status-kind";
import type { MealEstimationStatus } from "../../meal-estimation-status/domain/meal-estimation-status";
import type { MealEstimationStatusStore } from "../../meal-estimation-status/domain/meal-estimation-status-store";
import type { EstimationEventWriteStore } from "./estimation-event-write-store";
import type { EstimationWrites } from "./estimation-writes";

// 推定の書き込みの口。推定の予定と結果は、ここを通して書く。
// 書いた食事ごとに、初めて書く前と run のあとの推定の状態を推定の状態の種類で出し、
// 違う食事にだけ、書いた食事の順に推定の状態の変更を足す。addChange は帳簿の changeOutsideWrites のもの
export const writeEstimationEvents = <T>(
  stores: {
    meal: MealStore;
    mealEstimationStatus: MealEstimationStatusStore;
    estimationEventWrite: EstimationEventWriteStore;
  },
  addChange: (change: RecordChangeTarget<"meal_estimation_status">) => void,
  run: (writes: EstimationWrites) => T,
): T => {
  const statusKind = createMealEstimationStatusKind(stores.meal, stores.mealEstimationStatus);
  const store = stores.estimationEventWrite;
  const statusesBeforeWrites = new Map<string, CurrentRecord<MealEstimationStatus>>();
  const rememberStatusBeforeWrites = (mealId: string) => {
    if (!statusesBeforeWrites.has(mealId)) {
      statusesBeforeWrites.set(mealId, statusKind.readCurrent(mealId));
    }
  };

  const result = run({
    scheduleMeal: (schedule) => {
      rememberStatusBeforeWrites(schedule.mealId);
      store.insertMealSchedule(schedule);
    },
    deferToNextDay: ({ scheduleId, mealId, deferredAt, nextSchedule }) => {
      rememberStatusBeforeWrites(mealId);
      store.insertDeferral({ scheduleId, deferredAt });
      store.insertMealSchedule({ ...nextSchedule, mealId });
    },
    beginEstimation: ({ mealId, ...estimation }) => {
      rememberStatusBeforeWrites(mealId);
      store.insertEstimation(estimation);
    },
    beginAttempt: (attempt) => {
      store.insertAttempt(attempt);
    },
    recordAttemptResult: (attemptResult) => {
      store.insertAttemptResult(attemptResult);
    },
    complete: ({ mealId, ...completion }) => {
      rememberStatusBeforeWrites(mealId);
      store.insertCompletion(completion);
    },
    abandon: ({ mealId, ...abandonment }) => {
      rememberStatusBeforeWrites(mealId);
      store.insertAbandonment(abandonment);
    },
  });

  for (const [mealId, before] of statusesBeforeWrites) {
    if (!isSameStatus(before, statusKind.readCurrent(mealId))) {
      addChange({ recordType: "meal_estimation_status", recordId: mealId });
    }
  }
  return result;
};

const isSameStatus = (
  a: CurrentRecord<MealEstimationStatus>,
  b: CurrentRecord<MealEstimationStatus>,
): boolean =>
  a.status === "value" && b.status === "value" ? a.value === b.value : a.status === b.status;
