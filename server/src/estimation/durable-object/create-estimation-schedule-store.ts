import { and, desc, eq, isNull, min } from "drizzle-orm";
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
  findLatestTimeZone: () =>
    db
      .select({ timeZone: syncRequestLogs.timeZone })
      .from(syncRequestLogs)
      .orderBy(desc(syncRequestLogs.receivedAt))
      .limit(1)
      .get()?.timeZone,
});
