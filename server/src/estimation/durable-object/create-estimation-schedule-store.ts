import { and, asc, eq, gte, isNotNull, isNull, lte, min, ne } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { EstimationScheduleStore } from "../domain/estimation-schedule-store";
import { estimationScheduleTargets } from "./estimation-schedule-targets";
import { estimationTables } from "./estimation-tables";

const {
  estimationSchedules,
  mealEstimationSchedules,
  estimationDeferrals,
  estimationHolds,
  estimations,
  estimationScheduleCancellations,
} = estimationTables;

export const createEstimationScheduleStore = (
  db: DrizzleSqliteDODatabase,
): EstimationScheduleStore => ({
  hasScheduleOfMeal: (mealId) =>
    db
      .select({ id: mealEstimationSchedules.estimationScheduleId })
      .from(mealEstimationSchedules)
      .where(eq(mealEstimationSchedules.mealId, mealId))
      .get() !== undefined,
  findWaitingSchedules: (dueBy) => {
    const targets = estimationScheduleTargets.subquery(db);
    return (
      db
        .select({
          scheduleId: estimationSchedules.id,
          dueAt: estimationSchedules.dueAt,
          countedOn: estimationSchedules.countedOn,
          mealId: targets.mealId,
          dishId: targets.dishId,
        })
        .from(estimationSchedules)
        .innerJoin(targets, eq(targets.estimationScheduleId, estimationSchedules.id))
        .leftJoin(estimations, eq(estimations.estimationScheduleId, estimationSchedules.id))
        .leftJoin(
          estimationDeferrals,
          eq(estimationDeferrals.estimationScheduleId, estimationSchedules.id),
        )
        .leftJoin(estimationHolds, eq(estimationHolds.estimationScheduleId, estimationSchedules.id))
        // 取り消すのは料理の予定だけだが、食事の予定には取り消しの行が無いので、同じ条件で見る
        .leftJoin(
          estimationScheduleCancellations,
          eq(estimationScheduleCancellations.estimationScheduleId, estimationSchedules.id),
        )
        .where(
          and(
            isNull(estimations.id),
            isNull(estimationDeferrals.estimationScheduleId),
            isNull(estimationHolds.estimationScheduleId),
            isNull(estimationScheduleCancellations.estimationScheduleId),
            dueBy === undefined ? undefined : lte(estimationSchedules.dueAt, dueBy),
          ),
        )
        // 同じ時刻なら食事の予定を先にする（食事と料理を別に引いて並べていたときの順）
        .orderBy(asc(estimationSchedules.dueAt), isNotNull(targets.dishId))
        .all()
        .map(({ scheduleId, dueAt, countedOn, mealId, dishId }) => ({
          scheduleId,
          dueAt,
          countedOn,
          target: estimationScheduleTargets.toTarget({ mealId, dishId }),
        }))
    );
  },
  // 保留は1人に食事の数ほどしか無いので、保留ごとに、同じ対象のそれより新しい予定があるかを引く
  findHeldTargets: () => {
    const targets = estimationScheduleTargets.subquery(db);
    return db
      .select({
        scheduleId: estimationSchedules.id,
        dueAt: estimationSchedules.dueAt,
        mealId: targets.mealId,
        dishId: targets.dishId,
      })
      .from(estimationHolds)
      .innerJoin(
        estimationSchedules,
        eq(estimationSchedules.id, estimationHolds.estimationScheduleId),
      )
      .innerJoin(targets, eq(targets.estimationScheduleId, estimationSchedules.id))
      .orderBy(asc(estimationSchedules.dueAt), isNotNull(targets.dishId))
      .all()
      .filter((held) => {
        const sameTarget = estimationScheduleTargets.subquery(db);
        return (
          db
            .select({ id: estimationSchedules.id })
            .from(estimationSchedules)
            .innerJoin(sameTarget, eq(sameTarget.estimationScheduleId, estimationSchedules.id))
            .leftJoin(
              estimationScheduleCancellations,
              eq(estimationScheduleCancellations.estimationScheduleId, estimationSchedules.id),
            )
            .where(
              and(
                held.dishId === null
                  ? and(eq(sameTarget.mealId, held.mealId), isNull(sameTarget.dishId))
                  : eq(sameTarget.dishId, held.dishId),
                ne(estimationSchedules.id, held.scheduleId),
                gte(estimationSchedules.dueAt, held.dueAt),
                isNull(estimationScheduleCancellations.estimationScheduleId),
              ),
            )
            .get() === undefined
        );
      })
      .map(({ mealId, dishId }) => estimationScheduleTargets.toTarget({ mealId, dishId }));
  },
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
});
