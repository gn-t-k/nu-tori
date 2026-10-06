import { desc, eq, sql } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { estimationTables } from "../../estimation/durable-object/estimation-tables";
import { dishTables } from "./dish-tables";

const { dishEstimationApplications, dishEstimatedQuantities } = dishTables;
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
    .orderBy(...newestFirst)
    .limit(1)
    .get()?.estimationId;

// 量を持ついちばん新しい当てた推定の量と単位
export const findNewestDishEstimatedQuantity = (
  db: DrizzleSqliteDODatabase,
  dishId: string,
): { quantity: number; unit: string } | undefined =>
  db
    .select({ quantity: dishEstimatedQuantities.quantity, unit: dishEstimatedQuantities.unit })
    .from(dishEstimatedQuantities)
    .innerJoin(estimations, eq(estimations.id, dishEstimatedQuantities.estimationId))
    .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
    .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
    .where(eq(dishEstimatedQuantities.dishId, dishId))
    .orderBy(...newestFirst)
    .limit(1)
    .get();

// 当てた推定の新しさは、推定の終わり（完了か断念）の時刻で並べ、同じなら始めた時刻で並べる。
// 推定は終わったときにだけ当てるので、どちらかの時刻を必ず持つ
const newestFirst = [
  desc(sql`coalesce(${estimationCompletions.completedAt}, ${estimationAbandonments.abandonedAt})`),
  desc(estimations.startedAt),
];
