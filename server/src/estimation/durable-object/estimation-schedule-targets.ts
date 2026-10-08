import { eq, sql } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { dishTables } from "../../dish/durable-object/dish-tables";
import type { RecordId } from "../../domain/record-id";
import type { EstimationTarget } from "../domain/estimation-target";
import { estimationTables } from "./estimation-tables";

const { mealEstimationSchedules } = estimationTables;
const { dishes, dishEstimationSchedules } = dishTables;

// 推定の予定と、その対象の食事か料理を1つの問い合わせで引く。食事が対象と料理が対象で同じ問い合わせを2本書かずに済むよう、
// 予定の置き場と推定の置き場は、これと結合して対象を読む
export const estimationScheduleTargets = {
  // 料理の予定は、料理の行が残っているものだけ。料理を消すと、その予定の対象は無くなる
  subquery: (db: DrizzleSqliteDODatabase) =>
    db
      .select({
        estimationScheduleId: mealEstimationSchedules.estimationScheduleId,
        mealId: mealEstimationSchedules.mealId,
        dishId: sql<RecordId | null>`null`.as("dish_id"),
      })
      .from(mealEstimationSchedules)
      .unionAll(
        db
          .select({
            estimationScheduleId: dishEstimationSchedules.estimationScheduleId,
            mealId: dishes.mealId,
            dishId: dishEstimationSchedules.dishId,
          })
          .from(dishEstimationSchedules)
          .innerJoin(dishes, eq(dishes.id, dishEstimationSchedules.dishId)),
      )
      .as("estimation_schedule_targets"),
  toTarget: ({
    mealId,
    dishId,
  }: {
    mealId: RecordId;
    dishId: RecordId | null;
  }): EstimationTarget =>
    dishId === null ? { type: "meal", mealId } : { type: "dish", dishId, mealId },
};
