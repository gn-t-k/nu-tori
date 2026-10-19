import { desc, eq, isNull } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { alias } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import type { Goal } from "../domain/goal";
import type { GoalStore } from "../domain/goal-store";
import { goalTables } from "./goal-tables";

const {
  goals,
  weightChangeGoals,
  goalClosures,
  goalDecisionReceipts,
  goalAchievements,
  goalDeadlineConfirmations,
  postDeadlineMaintenanceGoals,
} = goalTables;
// 目標を閉じた次の目標。終わった日は、次の目標の開始の日から出す
const nextGoals = alias(goals, "next_goals");

export const createGoalStore = (db: DrizzleSqliteDODatabase): GoalStore => {
  const find = (id: RecordId): Goal | undefined => {
    const row = db
      .select({
        goal: goals,
        weightChange: {
          deadlineOn: weightChangeGoals.deadlineOn,
          pacePlan: weightChangeGoals.pacePlan,
        },
        achievement: {
          achievedOn: goalAchievements.achievedOn,
          judgedAt: goalAchievements.judgedAt,
          timeZone: goalAchievements.timeZone,
        },
        deadlineConfirmation: {
          deadlineWeightTrendKg: goalDeadlineConfirmations.deadlineWeightTrendKg,
          confirmedAt: goalDeadlineConfirmations.confirmedAt,
          timeZone: goalDeadlineConfirmations.timeZone,
        },
        closure: { endedOn: nextGoals.startedOn, nextGoalId: nextGoals.id },
        // 次の目標が期限後の維持の目標なら、期限後の維持に移って閉じた
        nextGoalIsPostDeadlineMaintenance: postDeadlineMaintenanceGoals.goalId,
      })
      .from(goals)
      .leftJoin(weightChangeGoals, eq(weightChangeGoals.goalId, goals.id))
      .leftJoin(goalClosures, eq(goalClosures.goalId, goals.id))
      .leftJoin(nextGoals, eq(nextGoals.id, goalClosures.nextGoalId))
      .leftJoin(goalAchievements, eq(goalAchievements.goalId, goals.id))
      .leftJoin(goalDeadlineConfirmations, eq(goalDeadlineConfirmations.goalId, goals.id))
      .leftJoin(
        postDeadlineMaintenanceGoals,
        eq(postDeadlineMaintenanceGoals.goalId, goalClosures.nextGoalId),
      )
      .where(eq(goals.id, id))
      .get();
    if (row === undefined) {
      return undefined;
    }
    return {
      ...row.goal,
      weightChange: row.weightChange ?? undefined,
      achievement: row.achievement ?? undefined,
      deadlineConfirmation: row.deadlineConfirmation ?? undefined,
      closure:
        row.closure === null
          ? undefined
          : {
              ...row.closure,
              endReason:
                row.nextGoalIsPostDeadlineMaintenance === null
                  ? "switched"
                  : "moved_to_maintenance",
            },
    };
  };
  return {
    find,
    findAll: () =>
      db
        .select({ id: goals.id })
        .from(goals)
        .all()
        .flatMap(({ id }) => find(id) ?? []),
    // 閉じていない目標は書く口が1つに保つ。並びは、その日の1日の目安の引き方（開始の日、決めた時刻の順で遅いほう）に合わせる
    findCurrent: () => {
      const current = db
        .select({ id: goals.id })
        .from(goals)
        .leftJoin(goalClosures, eq(goalClosures.goalId, goals.id))
        .where(isNull(goalClosures.goalId))
        .orderBy(desc(goals.startedOn), desc(goals.decidedAt))
        .limit(1)
        .get();
      return current === undefined ? undefined : find(current.id);
    },
    findClosedBy: (nextGoalId) => {
      const closure = db
        .select({ goalId: goalClosures.goalId })
        .from(goalClosures)
        .where(eq(goalClosures.nextGoalId, nextGoalId))
        .get();
      return closure === undefined ? undefined : find(closure.goalId);
    },
    findByDecisionRequest: (requestId) => {
      const receipt = db
        .select({ goalId: goalDecisionReceipts.goalId })
        .from(goalDecisionReceipts)
        .where(eq(goalDecisionReceipts.id, requestId))
        .get();
      return receipt === undefined ? undefined : find(receipt.goalId);
    },
    insert: ({ weightChange, ...goal }) => {
      db.insert(goals).values(goal).run();
      if (weightChange !== undefined) {
        db.insert(weightChangeGoals)
          .values({ goalId: goal.id, ...weightChange })
          .run();
      }
    },
    insertClosure: (closure) => {
      db.insert(goalClosures).values(closure).run();
    },
    insertDecisionReceipt: ({ requestId, goalId }) => {
      db.insert(goalDecisionReceipts).values({ id: requestId, goalId }).run();
    },
    insertPostDeadlineMaintenance: (goalId) => {
      db.insert(postDeadlineMaintenanceGoals).values({ goalId }).run();
    },
    insertAchievement: (achievement) => {
      db.insert(goalAchievements).values(achievement).run();
    },
    insertDeadlineConfirmation: (confirmation) => {
      db.insert(goalDeadlineConfirmations).values(confirmation).run();
    },
  };
};
