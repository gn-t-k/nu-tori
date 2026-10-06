import { and, asc, count, eq, isNull } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { match, P } from "ts-pattern";
import type { EstimationAttemptConclusion } from "../domain/estimation-attempt-conclusion";
import type { EstimationAttemptResult } from "../domain/estimation-attempt-result";
import type { EstimationAttempt, EstimationStore } from "../domain/estimation-store";
import { dishTables } from "../../dish/durable-object/dish-tables";
import type { EstimationTarget } from "../domain/estimation-target";
import { estimationTables } from "./estimation-tables";

const {
  estimationSchedules,
  mealEstimationSchedules,
  estimations,
  estimationAttempts,
  estimationAttemptResults,
  estimationAttemptErrors,
  estimationCompletions,
  estimationAbandonments,
} = estimationTables;
const { dishes, dishEstimationSchedules } = dishTables;

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
            : { endedAt, conclusion: toConclusion(result, errorType) },
      }));

  return {
    countEstimationsCountedOn: (countedOn) =>
      db
        .select({ total: count() })
        .from(estimations)
        .innerJoin(
          estimationSchedules,
          eq(estimationSchedules.id, estimations.estimationScheduleId),
        )
        .where(eq(estimationSchedules.countedOn, countedOn))
        .get()?.total ?? 0,
    findContinuingEstimations: () => {
      const notEnded = and(
        isNull(estimationCompletions.estimationId),
        isNull(estimationAbandonments.estimationId),
      );
      const continuingOfMeals = db
        .select({ estimationId: estimations.id, mealId: mealEstimationSchedules.mealId })
        .from(estimations)
        .innerJoin(
          mealEstimationSchedules,
          eq(mealEstimationSchedules.estimationScheduleId, estimations.estimationScheduleId),
        )
        .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
        .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
        .where(notEnded)
        .all()
        .map(({ estimationId, mealId }) => ({
          estimationId,
          target: { type: "meal" as const, mealId },
        }));
      const continuingOfDishes = db
        .select({
          estimationId: estimations.id,
          dishId: dishEstimationSchedules.dishId,
          mealId: dishes.mealId,
        })
        .from(estimations)
        .innerJoin(
          dishEstimationSchedules,
          eq(dishEstimationSchedules.estimationScheduleId, estimations.estimationScheduleId),
        )
        .innerJoin(dishes, eq(dishes.id, dishEstimationSchedules.dishId))
        .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
        .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
        .where(notEnded)
        .all()
        .map(({ estimationId, dishId, mealId }) => ({
          estimationId,
          target: { type: "dish" as const, dishId, mealId },
        }));
      return [...continuingOfMeals, ...continuingOfDishes].map(({ estimationId, target }) => ({
        estimationId,
        target,
        attempts: findAttempts(estimationId),
      }));
    },
    findTargetOfEstimation: (estimationId): EstimationTarget | undefined => {
      const meal = db
        .select({ mealId: mealEstimationSchedules.mealId })
        .from(estimations)
        .innerJoin(
          mealEstimationSchedules,
          eq(mealEstimationSchedules.estimationScheduleId, estimations.estimationScheduleId),
        )
        .where(eq(estimations.id, estimationId))
        .get();
      if (meal !== undefined) {
        return { type: "meal", mealId: meal.mealId };
      }
      const dish = db
        .select({ dishId: dishEstimationSchedules.dishId, mealId: dishes.mealId })
        .from(estimations)
        .innerJoin(
          dishEstimationSchedules,
          eq(dishEstimationSchedules.estimationScheduleId, estimations.estimationScheduleId),
        )
        .innerJoin(dishes, eq(dishes.id, dishEstimationSchedules.dishId))
        .where(eq(estimations.id, estimationId))
        .get();
      return dish === undefined ? undefined : { type: "dish", ...dish };
    },
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
  };
};

// 提供元のエラーと 400 の結果には、同じトランザクションでエラーの種類を書いている
const toConclusion = (
  result: EstimationAttemptResult,
  errorType: string | null,
): EstimationAttemptConclusion =>
  match(result)
    .with(P.union("provider_error", "bad_request"), (providerResult) => {
      if (errorType === null) {
        throw new Error(`提供元のエラーの試みに、エラーの種類が無い: ${providerResult}`);
      }
      return { result: providerResult, errorType };
    })
    .with(P.union("succeeded", "timed_out", "invalid_response"), (otherResult) => ({
      result: otherResult,
    }))
    .exhaustive();
