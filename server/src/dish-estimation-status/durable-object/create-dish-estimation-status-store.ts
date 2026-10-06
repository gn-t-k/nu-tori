import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { dishTables } from "../../dish/durable-object/dish-tables";
import { estimationTables } from "../../estimation/durable-object/estimation-tables";
import type { DishEstimationSchedule } from "../domain/dish-estimation-schedule";
import type { DishEstimationStatusStore } from "../domain/dish-estimation-status-store";

const { dishEstimationSchedules } = dishTables;
const {
  estimationSchedules,
  estimationDeferrals,
  estimations,
  estimationCompletions,
  estimationAbandonments,
  estimationScheduleCancellations,
} = estimationTables;

export const createDishEstimationStatusStore = (
  db: DrizzleSqliteDODatabase,
): DishEstimationStatusStore => ({
  findSchedulesOfDish: (dishId) =>
    db
      .select({
        scheduleId: estimationSchedules.id,
        dueAt: estimationSchedules.dueAt,
        cancellation: estimationScheduleCancellations.estimationScheduleId,
        deferral: estimationDeferrals.estimationScheduleId,
        estimation: estimations.id,
        completion: estimationCompletions.result,
        abandonment: estimationAbandonments.estimationId,
      })
      .from(dishEstimationSchedules)
      .innerJoin(
        estimationSchedules,
        eq(estimationSchedules.id, dishEstimationSchedules.estimationScheduleId),
      )
      .leftJoin(
        estimationScheduleCancellations,
        eq(estimationScheduleCancellations.estimationScheduleId, estimationSchedules.id),
      )
      .leftJoin(
        estimationDeferrals,
        eq(estimationDeferrals.estimationScheduleId, estimationSchedules.id),
      )
      .leftJoin(estimations, eq(estimations.estimationScheduleId, estimationSchedules.id))
      .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
      .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
      .where(eq(dishEstimationSchedules.dishId, dishId))
      .all()
      .map(({ scheduleId, dueAt, cancellation, estimation, ...events }) => ({
        scheduleId,
        dueAt,
        cancelled: cancellation !== null,
        progress: toProgress({ estimation, ...events }),
        estimationId: estimation ?? undefined,
      })),
});

const toProgress = (events: {
  deferral: string | null;
  estimation: string | null;
  completion: "estimated" | "no_dishes" | null;
  abandonment: string | null;
}): DishEstimationSchedule["progress"] => {
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
