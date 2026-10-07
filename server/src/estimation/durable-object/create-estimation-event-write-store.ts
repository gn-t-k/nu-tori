import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { match, P } from "ts-pattern";
import type { EstimationEventWriteStore } from "../domain/estimation-event-write-store";
import { dishTables } from "../../dish/durable-object/dish-tables";
import { estimationTables } from "./estimation-tables";

const {
  estimationSchedules,
  mealEstimationSchedules,
  estimationDeferrals,
  estimations,
  estimationAttempts,
  estimationAttemptResults,
  estimationAttemptErrors,
  estimationCompletions,
  estimationAbandonments,
} = estimationTables;
const { dishEstimationSchedules } = dishTables;

export const createEstimationEventWriteStore = (
  db: DrizzleSqliteDODatabase,
): EstimationEventWriteStore => ({
  insertMealSchedule: ({ id, dueAt, countedOn, mealId }) => {
    db.insert(estimationSchedules).values({ id, dueAt, countedOn }).run();
    db.insert(mealEstimationSchedules).values({ estimationScheduleId: id, mealId }).run();
  },
  insertDishSchedule: ({ id, dueAt, countedOn, dishId }) => {
    db.insert(estimationSchedules).values({ id, dueAt, countedOn }).run();
    db.insert(dishEstimationSchedules).values({ estimationScheduleId: id, dishId }).run();
  },
  insertDeferral: ({ scheduleId, deferredAt }) => {
    db.insert(estimationDeferrals).values({ estimationScheduleId: scheduleId, deferredAt }).run();
  },
  insertEstimation: ({ id, scheduleId, startedAt }) => {
    db.insert(estimations).values({ id, estimationScheduleId: scheduleId, startedAt }).run();
  },
  insertAttempt: (attempt) => {
    db.insert(estimationAttempts).values(attempt).run();
  },
  insertAttemptResult: ({ attemptId, endedAt, conclusion }) => {
    db.insert(estimationAttemptResults)
      .values({ estimationAttemptId: attemptId, endedAt, result: conclusion.result })
      .run();
    match(conclusion)
      .with({ result: P.union("succeeded", "timed_out", "invalid_response") }, () => undefined)
      .with({ result: P.union("provider_error", "bad_request") }, ({ errorType }) => {
        db.insert(estimationAttemptErrors)
          .values({ estimationAttemptId: attemptId, errorType })
          .run();
      })
      .exhaustive();
  },
  insertCompletion: (completion) => {
    db.insert(estimationCompletions).values(completion).run();
  },
  insertAbandonment: (abandonment) => {
    db.insert(estimationAbandonments).values(abandonment).run();
  },
});
