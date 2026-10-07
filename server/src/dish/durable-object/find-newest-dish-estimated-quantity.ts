import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { estimationTables } from "../../estimation/durable-object/estimation-tables";
import { dishTables } from "./dish-tables";
import { newestDishEstimationFirst } from "./newest-dish-estimation-first";

const { dishEstimatedQuantities } = dishTables;
const { estimations, estimationCompletions, estimationAbandonments } = estimationTables;

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
    .orderBy(...newestDishEstimationFirst)
    .limit(1)
    .get();
