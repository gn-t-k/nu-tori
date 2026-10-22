import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { estimationTables } from "../../estimation/durable-object/estimation-tables";
import { sentTextTables } from "../../sent-text/durable-object/sent-text-tables";
import type {
  MealEstimationScheduleState,
  MealEstimationStatusStore,
} from "../domain/meal-estimation-status-store";

const {
  estimationSchedules,
  mealEstimationSchedules,
  estimationDeferrals,
  estimationHolds,
  estimations,
  estimationCompletions,
  estimationAbandonments,
} = estimationTables;
const { estimationCreatedMeals } = sentTextTables;

export const createMealEstimationStatusStore = (
  db: DrizzleSqliteDODatabase,
): MealEstimationStatusStore => ({
  // 推定が作った2つめ以降の文章の食事は、予定のつなぎを持たず、作った推定の予定から出す（#419 の設計判断 26）
  findSchedulesOfMeal: (mealId) =>
    [
      ...db
        .select({
          dueAt: estimationSchedules.dueAt,
          deferral: estimationDeferrals.estimationScheduleId,
          hold: estimationHolds.estimationScheduleId,
          estimation: estimations.id,
          completion: estimationCompletions.result,
          abandonment: estimationAbandonments.estimationId,
        })
        .from(mealEstimationSchedules)
        .innerJoin(
          estimationSchedules,
          eq(estimationSchedules.id, mealEstimationSchedules.estimationScheduleId),
        )
        .leftJoin(
          estimationDeferrals,
          eq(estimationDeferrals.estimationScheduleId, estimationSchedules.id),
        )
        .leftJoin(estimationHolds, eq(estimationHolds.estimationScheduleId, estimationSchedules.id))
        .leftJoin(estimations, eq(estimations.estimationScheduleId, estimationSchedules.id))
        .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
        .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
        .where(eq(mealEstimationSchedules.mealId, mealId))
        .all(),
      ...db
        .select({
          dueAt: estimationSchedules.dueAt,
          deferral: estimationDeferrals.estimationScheduleId,
          hold: estimationHolds.estimationScheduleId,
          estimation: estimations.id,
          completion: estimationCompletions.result,
          abandonment: estimationAbandonments.estimationId,
        })
        .from(estimationCreatedMeals)
        .innerJoin(estimations, eq(estimations.id, estimationCreatedMeals.estimationId))
        .innerJoin(
          estimationSchedules,
          eq(estimationSchedules.id, estimations.estimationScheduleId),
        )
        .leftJoin(
          estimationDeferrals,
          eq(estimationDeferrals.estimationScheduleId, estimationSchedules.id),
        )
        .leftJoin(estimationHolds, eq(estimationHolds.estimationScheduleId, estimationSchedules.id))
        .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
        .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
        .where(eq(estimationCreatedMeals.mealId, mealId))
        .all(),
    ].map(({ dueAt, ...events }) => ({ dueAt, ...toProgress(events) })),
});

const toProgress = (events: {
  deferral: string | null;
  hold: string | null;
  estimation: string | null;
  completion: "estimated" | "no_dishes" | null;
  abandonment: string | null;
}): MealEstimationScheduleState => {
  if (events.deferral !== null) {
    return { progress: "deferred" };
  }
  if (events.hold !== null) {
    return { progress: "held" };
  }
  if (events.estimation === null) {
    return { progress: "waiting" };
  }
  const estimationId = events.estimation;
  if (events.completion !== null) {
    return { progress: events.completion, estimationId };
  }
  return { progress: events.abandonment === null ? "estimating" : "abandoned", estimationId };
};
