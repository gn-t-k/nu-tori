import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { alias } from "drizzle-orm/sqlite-core";
import type { GoalStore } from "../domain/goal-store";
import { goalTables } from "./goal-tables";

const { goals, weightChangeGoals, goalClosures } = goalTables;
// 目標を閉じた次の目標。終わった日は、次の目標の開始の日から出す
const nextGoals = alias(goals, "next_goals");

export const createGoalStore = (db: DrizzleSqliteDODatabase): GoalStore => ({
  find: (id) => {
    const row = db
      .select({
        goal: goals,
        weightChange: {
          deadlineOn: weightChangeGoals.deadlineOn,
          pacePlan: weightChangeGoals.pacePlan,
        },
        closure: { endedOn: nextGoals.startedOn, nextGoalId: nextGoals.id },
      })
      .from(goals)
      .leftJoin(weightChangeGoals, eq(weightChangeGoals.goalId, goals.id))
      .leftJoin(goalClosures, eq(goalClosures.goalId, goals.id))
      .leftJoin(nextGoals, eq(nextGoals.id, goalClosures.nextGoalId))
      .where(eq(goals.id, id))
      .get();
    if (row === undefined) {
      return undefined;
    }
    return {
      ...row.goal,
      weightChange: row.weightChange ?? undefined,
      closure: row.closure ?? undefined,
    };
  },
});
