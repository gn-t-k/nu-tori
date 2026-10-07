import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { estimationTables } from "../../estimation/durable-object/estimation-tables";
import { dishTables } from "./dish-tables";
import { newestDishEstimationFirst } from "./newest-dish-estimation-first";

const { dishEstimationApplications } = dishTables;
const { estimations, estimationCompletions, estimationAbandonments } = estimationTables;

// 料理のいちばん新しい当てた推定の ID。今の材料は、この推定の材料
export const findNewestDishEstimationId = (
  db: DrizzleSqliteDODatabase,
  dishId: string,
): string | undefined =>
  db
    .select({ estimationId: dishEstimationApplications.estimationId })
    .from(dishEstimationApplications)
    .innerJoin(estimations, eq(estimations.id, dishEstimationApplications.estimationId))
    .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
    .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
    .where(eq(dishEstimationApplications.dishId, dishId))
    .orderBy(...newestDishEstimationFirst)
    .limit(1)
    .get()?.estimationId;
