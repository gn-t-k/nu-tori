import { integer, real, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { pacePlans } from "../domain/goal";

const goals = sqliteTable("goals", {
  id: text("id").$type<RecordId>().primaryKey(),
  startedOn: text("started_on").notNull(),
  startingWeightTrendKg: real("starting_weight_trend_kg").notNull(),
  targetWeightKg: real("target_weight_kg").notNull(),
  decidedAt: integer("decided_at", { mode: "timestamp_ms" }).notNull(),
  timeZone: text("time_zone").notNull(),
});

// 減量・増量の目標のサブセット。行の無い目標は維持
const weightChangeGoals = sqliteTable("weight_change_goals", {
  goalId: text("goal_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => goals.id),
  deadlineOn: text("deadline_on").notNull(),
  pacePlan: text("pace_plan", { enum: pacePlans }).notNull(),
});

// 目標を閉じる。終わった日と閉じた時刻は、次の目標の開始の日と決めた時刻から出す
const goalClosures = sqliteTable(
  "goal_closures",
  {
    goalId: text("goal_id")
      .$type<RecordId>()
      .primaryKey()
      .references(() => goals.id),
    nextGoalId: text("next_goal_id")
      .$type<RecordId>()
      .notNull()
      .references(() => goals.id),
  },
  (table) => [uniqueIndex("goal_closures_next_goal_id").on(table.nextGoalId)],
);

// 目標を決める要求の受け取り。ID は端末が振った要求の ID。消さない
const goalDecisionReceipts = sqliteTable(
  "goal_decision_receipts",
  {
    id: text("id").primaryKey(),
    goalId: text("goal_id")
      .$type<RecordId>()
      .notNull()
      .references(() => goals.id),
  },
  (table) => [uniqueIndex("goal_decision_receipts_goal_id").on(table.goalId)],
);

// 減量・増量の目標の達成（#613）。達成した日はスナップショットで持つ
const goalAchievements = sqliteTable("goal_achievements", {
  goalId: text("goal_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => weightChangeGoals.goalId),
  achievedOn: text("achieved_on").notNull(),
  judgedAt: integer("judged_at", { mode: "timestamp_ms" }).notNull(),
  timeZone: text("time_zone").notNull(),
});

// 減量・増量の目標の期限の日の確定（#613）。期限の日の体重の傾向はスナップショットで持つ
const goalDeadlineConfirmations = sqliteTable("goal_deadline_confirmations", {
  goalId: text("goal_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => weightChangeGoals.goalId),
  deadlineWeightTrendKg: real("deadline_weight_trend_kg").notNull(),
  confirmedAt: integer("confirmed_at", { mode: "timestamp_ms" }).notNull(),
  timeZone: text("time_zone").notNull(),
});

// 期限後の維持の目標のサブセット（#613）。移った時刻は目標の decided_at、前の目標は goal_closures から出す
const postDeadlineMaintenanceGoals = sqliteTable("post_deadline_maintenance_goals", {
  goalId: text("goal_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => goals.id),
});

// 目標の表（#523・#613）。どの表も書き足すだけ。宣言は durable-object-migrations/ の SQL に合わせる
export const goalTables = {
  goals,
  weightChangeGoals,
  goalClosures,
  goalDecisionReceipts,
  goalAchievements,
  goalDeadlineConfirmations,
  postDeadlineMaintenanceGoals,
};
