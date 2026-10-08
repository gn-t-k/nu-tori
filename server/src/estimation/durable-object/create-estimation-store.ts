import { and, asc, count, eq, isNotNull, isNull } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { match, P } from "ts-pattern";
import type { EstimationAttemptConclusion } from "../domain/estimation-attempt-conclusion";
import type { EstimationAttemptResult } from "../domain/estimation-attempt-result";
import type { EstimationAttempt, EstimationStore } from "../domain/estimation-store";
import { estimationScheduleTargets } from "./estimation-schedule-targets";
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
      const targets = estimationScheduleTargets.subquery(db);
      return (
        db
          .select({ estimationId: estimations.id, mealId: targets.mealId, dishId: targets.dishId })
          .from(estimations)
          .innerJoin(targets, eq(targets.estimationScheduleId, estimations.estimationScheduleId))
          .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
          .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
          .where(
            and(
              isNull(estimationCompletions.estimationId),
              isNull(estimationAbandonments.estimationId),
            ),
          )
          // 食事が対象の推定を先にする（食事と料理を別に引いて並べていたときの順）
          .orderBy(isNotNull(targets.dishId))
          .all()
          .map(({ estimationId, mealId, dishId }) => ({
            estimationId,
            target: estimationScheduleTargets.toTarget({ mealId, dishId }),
            attempts: findAttempts(estimationId),
          }))
      );
    },
    findTargetOfEstimation: (estimationId) => {
      const targets = estimationScheduleTargets.subquery(db);
      const found = db
        .select({ mealId: targets.mealId, dishId: targets.dishId })
        .from(estimations)
        .innerJoin(targets, eq(targets.estimationScheduleId, estimations.estimationScheduleId))
        .where(eq(estimations.id, estimationId))
        .get();
      return found === undefined ? undefined : estimationScheduleTargets.toTarget(found);
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
