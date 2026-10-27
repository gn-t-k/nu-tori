import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { toEstimationSchedule } from "../../estimation/domain/to-estimation-schedule";
import { estimationTables } from "../../estimation/durable-object/estimation-tables";
import { sentTextTables } from "../../sent-text/durable-object/sent-text-tables";
import type { MealEstimationStatusStore } from "../domain/meal-estimation-status-store";

const {
  estimationSchedules,
  mealEstimationSchedules,
  estimationDeferrals,
  estimationHolds,
  estimations,
  estimationCompletions,
  estimationAbandonments,
  estimationScheduleCancellations,
} = estimationTables;
const { estimationCreatedMeals } = sentTextTables;

export const createMealEstimationStatusStore = (
  db: DrizzleSqliteDODatabase,
): MealEstimationStatusStore => ({
  // 食事の予定には取り消しの行が無いが、料理の予定と同じ出来事の形で読む。
  // 推定が作った2つめ以降の文章の食事は、予定のつなぎを持たず、作った推定の予定から出す（#419 の設計判断 26）
  findSchedulesOfMeal: (mealId) =>
    [
      ...db
        .select({
          scheduleId: estimationSchedules.id,
          dueAt: estimationSchedules.dueAt,
          cancellation: estimationScheduleCancellations.estimationScheduleId,
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
          estimationScheduleCancellations,
          eq(estimationScheduleCancellations.estimationScheduleId, estimationSchedules.id),
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
          scheduleId: estimationSchedules.id,
          dueAt: estimationSchedules.dueAt,
          cancellation: estimationScheduleCancellations.estimationScheduleId,
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
          estimationScheduleCancellations,
          eq(estimationScheduleCancellations.estimationScheduleId, estimationSchedules.id),
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
    ].map(toEstimationSchedule),
});
