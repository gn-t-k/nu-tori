import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { ExpenditureEstimateStore } from "../domain/expenditure-estimate-store";
import { expenditureEstimateTables } from "./expenditure-estimate-tables";

const { expenditureEstimates, initialExpenditureEstimates } = expenditureEstimateTables;

export const createExpenditureEstimateStore = (
  db: DrizzleSqliteDODatabase,
): ExpenditureEstimateStore => ({
  find: (id) => {
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
  },
});
