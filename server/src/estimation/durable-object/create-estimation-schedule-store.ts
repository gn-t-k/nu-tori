import { and, asc, desc, eq, isNull, lte, min } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import type { EstimationScheduleStore } from "../domain/estimation-schedule-store";
import { estimationTables } from "./estimation-tables";

const { syncRequestLogs } = syncLedgerTables;
const { estimationSchedules, mealEstimationSchedules, estimationDeferrals, estimations } =
  estimationTables;

export const createEstimationScheduleStore = (
  db: DrizzleSqliteDODatabase,
): EstimationScheduleStore => ({
  hasScheduleOfMeal: (mealId) =>
    db
      .select({ id: mealEstimationSchedules.estimationScheduleId })
      .from(mealEstimationSchedules)
      .where(eq(mealEstimationSchedules.mealId, mealId))
      .get() !== undefined,
  insertMealSchedule: ({ id, dueAt, countedOn, mealId }) => {
    db.insert(estimationSchedules).values({ id, dueAt, countedOn }).run();
    db.insert(mealEstimationSchedules).values({ estimationScheduleId: id, mealId }).run();
  },
  findEarliestWaitingDueAt: () =>
    db
      .select({ dueAt: min(estimationSchedules.dueAt) })
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
      .where(and(isNull(estimations.id), isNull(estimationDeferrals.estimationScheduleId)))
      .get()?.dueAt ?? undefined,
  findDueWaitingSchedules: (now) =>
    db
      .select({
        scheduleId: estimationSchedules.id,
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
          lte(estimationSchedules.dueAt, now),
        ),
      )
      .orderBy(asc(estimationSchedules.dueAt))
      .all(),
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
  findLatestTimeZone: () =>
    db
      .select({ timeZone: syncRequestLogs.timeZone })
      .from(syncRequestLogs)
      .orderBy(desc(syncRequestLogs.receivedAt))
      .limit(1)
      .get()?.timeZone,
});
