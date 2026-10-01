import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { estimationTables } from "../../estimation/durable-object/estimation-tables";
import type { MealEstimationStatusStore } from "../domain/meal-estimation-status-store";

const {
  estimationSchedules,
  mealEstimationSchedules,
  estimationDeferrals,
  estimations,
  estimationCompletions,
  estimationAbandonments,
} = estimationTables;

export const createMealEstimationStatusStore = (
  db: DrizzleSqliteDODatabase,
): MealEstimationStatusStore => ({
  findSchedulesOfMeal: (mealId) =>
    db
      .select({
        dueAt: estimationSchedules.dueAt,
        deferral: estimationDeferrals.estimationScheduleId,
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
      .leftJoin(estimations, eq(estimations.estimationScheduleId, estimationSchedules.id))
      .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
      .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
      .where(eq(mealEstimationSchedules.mealId, mealId))
      .all()
      .map(({ dueAt, deferral, estimation, completion, abandonment }) => ({
        dueAt,
        progress: toProgress({ deferral, estimation, completion, abandonment }),
      })),
});

const toProgress = (events: {
  deferral: string | null;
  estimation: string | null;
  completion: "estimated" | "no_dishes" | null;
  abandonment: string | null;
}): ReturnType<MealEstimationStatusStore["findSchedulesOfMeal"]>[number]["progress"] => {
  if (events.deferral !== null) {
    return "deferred";
  }
  if (events.estimation === null) {
    return "waiting";
  }
  if (events.completion !== null) {
    return events.completion;
  }
  return events.abandonment === null ? "estimating" : "abandoned";
};
