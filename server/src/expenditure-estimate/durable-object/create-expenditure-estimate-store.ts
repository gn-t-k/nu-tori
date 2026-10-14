import { desc, eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { RecordId } from "../../domain/record-id";
import type { ExpenditureEstimate } from "../domain/expenditure-estimate";
import type { ExpenditureEstimateStore } from "../domain/expenditure-estimate-store";
import { expenditureEstimateTables } from "./expenditure-estimate-tables";

const { expenditureEstimates, initialExpenditureEstimates } = expenditureEstimateTables;

export const createExpenditureEstimateStore = (
  db: DrizzleSqliteDODatabase,
): ExpenditureEstimateStore => {
  const find = (id: RecordId): ExpenditureEstimate | undefined => {
    const row = db
      .select({ estimate: expenditureEstimates, initialSource: initialExpenditureEstimates.source })
      .from(expenditureEstimates)
      .leftJoin(
        initialExpenditureEstimates,
        eq(initialExpenditureEstimates.expenditureEstimateId, expenditureEstimates.id),
      )
      .where(eq(expenditureEstimates.id, id))
      .get();
    if (row === undefined) {
      return undefined;
    }
    return { ...row.estimate, initialSource: row.initialSource ?? undefined };
  };
  return {
    find,
    findCurrent: () => {
      const current = db
        .select({ id: expenditureEstimates.id })
        .from(expenditureEstimates)
        .orderBy(desc(expenditureEstimates.effectiveOn), desc(expenditureEstimates.estimatedAt))
        .limit(1)
        .get();
      return current === undefined ? undefined : find(current.id);
    },
    insert: ({ initialSource, ...estimate }) => {
      db.insert(expenditureEstimates).values(estimate).run();
      if (initialSource !== undefined) {
        db.insert(initialExpenditureEstimates)
          .values({ expenditureEstimateId: estimate.id, source: initialSource })
          .run();
      }
    },
  };
};
