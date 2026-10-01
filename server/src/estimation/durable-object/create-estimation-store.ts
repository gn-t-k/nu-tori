import { and, asc, eq, isNull } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { EstimationAttempt, EstimationStore } from "../domain/estimation-store";
import { estimationTables } from "./estimation-tables";

const {
  mealEstimationSchedules,
  estimations,
  estimationAttempts,
  estimationAttemptResults,
  estimationAttemptErrors,
  estimationCompletions,
  estimationAbandonments,
} = estimationTables;

export const createEstimationStore = (db: DrizzleSqliteDODatabase): EstimationStore => {
  const findAttempts = (estimationId: string): EstimationAttempt[] =>
    db
      .select({
        attemptedAt: estimationAttempts.attemptedAt,
        endedAt: estimationAttemptResults.endedAt,
        result: estimationAttemptResults.result,
        errorType: estimationAttemptErrors.errorType,
      })
      .from(estimationAttempts)
      .leftJoin(
        estimationAttemptResults,
        eq(estimationAttemptResults.estimationAttemptId, estimationAttempts.id),
      )
      .leftJoin(
        estimationAttemptErrors,
        eq(estimationAttemptErrors.estimationAttemptId, estimationAttempts.id),
      )
      .where(eq(estimationAttempts.estimationId, estimationId))
      .orderBy(asc(estimationAttempts.attemptedAt))
      .all()
      .map(({ attemptedAt, endedAt, result, errorType }) => ({
        attemptedAt,
        ended:
          endedAt === null || result === null
            ? undefined
            : { endedAt, result, errorType: errorType ?? undefined },
      }));

  return {
    insertEstimation: ({ id, scheduleId, startedAt }) => {
      db.insert(estimations).values({ id, estimationScheduleId: scheduleId, startedAt }).run();
    },
    insertAttempt: (attempt) => {
      db.insert(estimationAttempts).values(attempt).run();
    },
    findContinuingEstimations: () => {
      const continuing = db
        .select({ estimationId: estimations.id, mealId: mealEstimationSchedules.mealId })
        .from(estimations)
        .innerJoin(
          mealEstimationSchedules,
          eq(mealEstimationSchedules.estimationScheduleId, estimations.estimationScheduleId),
        )
        .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
        .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
        .where(
          and(
            isNull(estimationCompletions.estimationId),
            isNull(estimationAbandonments.estimationId),
          ),
        )
        .all();
      return continuing.map(({ estimationId, mealId }) => ({
        estimationId,
        mealId,
        attempts: findAttempts(estimationId),
      }));
    },
    findMealIdOfEstimation: (estimationId) =>
      db
        .select({ mealId: mealEstimationSchedules.mealId })
        .from(estimations)
        .innerJoin(
          mealEstimationSchedules,
          eq(mealEstimationSchedules.estimationScheduleId, estimations.estimationScheduleId),
        )
        .where(eq(estimations.id, estimationId))
        .get()?.mealId,
    findOngoingEstimationIdOfMeal: (mealId) =>
      db
        .select({ estimationId: estimations.id })
        .from(mealEstimationSchedules)
        .innerJoin(
          estimations,
          eq(estimations.estimationScheduleId, mealEstimationSchedules.estimationScheduleId),
        )
        .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
        .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
        .where(
          and(
            eq(mealEstimationSchedules.mealId, mealId),
            isNull(estimationCompletions.estimationId),
            isNull(estimationAbandonments.estimationId),
          ),
        )
        .get()?.estimationId,
    findAttempts,
    insertAttemptResult: ({ attemptId, endedAt, result, errorType }) => {
      db.insert(estimationAttemptResults)
        .values({ estimationAttemptId: attemptId, endedAt, result })
        .run();
      if (errorType !== undefined) {
        db.insert(estimationAttemptErrors)
          .values({ estimationAttemptId: attemptId, errorType })
          .run();
      }
    },
    insertCompletion: (completion) => {
      db.insert(estimationCompletions).values(completion).run();
    },
    insertAbandonment: (abandonment) => {
      db.insert(estimationAbandonments).values(abandonment).run();
    },
  };
};
