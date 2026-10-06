import { and, asc, eq, isNull, lte, min } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { dishTables } from "../../dish/durable-object/dish-tables";
import type { EstimationScheduleStore } from "../domain/estimation-schedule-store";
import { estimationTables } from "./estimation-tables";

const {
  estimationSchedules,
  mealEstimationSchedules,
  estimationDeferrals,
  estimations,
  estimationScheduleCancellations,
} = estimationTables;
const { dishes, dishEstimationSchedules } = dishTables;

export const createEstimationScheduleStore = (
  db: DrizzleSqliteDODatabase,
): EstimationScheduleStore => {
  // 待っている予定（推定も見送りも無い）。食事の予定は取り消さないので、取り消しは料理の予定だけを見る
  const waitingMealSchedules = (dueBy: Date | undefined) =>
    db
      .select({
        scheduleId: estimationSchedules.id,
        dueAt: estimationSchedules.dueAt,
        countedOn: estimationSchedules.countedOn,
        mealId: mealEstimationSchedules.mealId,
      })
      .from(estimationSchedules)
      .innerJoin(
        mealEstimationSchedules,
        eq(mealEstimationSchedules.estimationScheduleId, estimationSchedules.id),
      )
      .leftJoin(estimations, eq(estimations.estimationScheduleId, estimationSchedules.id))
      .leftJoin(
        estimationDeferrals,
        eq(estimationDeferrals.estimationScheduleId, estimationSchedules.id),
      )
      .where(
        and(
          isNull(estimations.id),
          isNull(estimationDeferrals.estimationScheduleId),
          dueBy === undefined ? undefined : lte(estimationSchedules.dueAt, dueBy),
        ),
      )
      .orderBy(asc(estimationSchedules.dueAt))
      .all();
  const waitingDishSchedules = (dueBy: Date | undefined) =>
    db
      .select({
        scheduleId: estimationSchedules.id,
        dueAt: estimationSchedules.dueAt,
        countedOn: estimationSchedules.countedOn,
        dishId: dishEstimationSchedules.dishId,
        mealId: dishes.mealId,
      })
      .from(estimationSchedules)
      .innerJoin(
        dishEstimationSchedules,
        eq(dishEstimationSchedules.estimationScheduleId, estimationSchedules.id),
      )
      .innerJoin(dishes, eq(dishes.id, dishEstimationSchedules.dishId))
      .leftJoin(estimations, eq(estimations.estimationScheduleId, estimationSchedules.id))
      .leftJoin(
        estimationDeferrals,
        eq(estimationDeferrals.estimationScheduleId, estimationSchedules.id),
      )
      .leftJoin(
        estimationScheduleCancellations,
        eq(estimationScheduleCancellations.estimationScheduleId, estimationSchedules.id),
      )
      .where(
        and(
          isNull(estimations.id),
          isNull(estimationDeferrals.estimationScheduleId),
          isNull(estimationScheduleCancellations.estimationScheduleId),
          dueBy === undefined ? undefined : lte(estimationSchedules.dueAt, dueBy),
        ),
      )
      .orderBy(asc(estimationSchedules.dueAt))
      .all();

  return {
    hasScheduleOfMeal: (mealId) =>
      db
        .select({ id: mealEstimationSchedules.estimationScheduleId })
        .from(mealEstimationSchedules)
        .where(eq(mealEstimationSchedules.mealId, mealId))
        .get() !== undefined,
    findWaitingSchedules: (dueBy) =>
      [
        ...waitingMealSchedules(dueBy).map(({ scheduleId, dueAt, countedOn, mealId }) => ({
          scheduleId,
          dueAt,
          countedOn,
          target: { type: "meal" as const, mealId },
        })),
        ...waitingDishSchedules(dueBy).map(({ scheduleId, dueAt, countedOn, dishId, mealId }) => ({
          scheduleId,
          dueAt,
          countedOn,
          target: { type: "dish" as const, dishId, mealId },
        })),
      ].toSorted((a, b) => a.dueAt.getTime() - b.dueAt.getTime()),
    findEarliestDueAtOfMeal: (mealId) =>
      db
        .select({ dueAt: min(estimationSchedules.dueAt) })
        .from(estimationSchedules)
        .innerJoin(
          mealEstimationSchedules,
          eq(mealEstimationSchedules.estimationScheduleId, estimationSchedules.id),
        )
        .where(eq(mealEstimationSchedules.mealId, mealId))
        .get()?.dueAt ?? undefined,
  };
};
