import {
  type AnySQLiteColumn,
  index,
  integer,
  sqliteTable,
  text,
  uniqueIndex,
} from "drizzle-orm/sqlite-core";
import { dishTables } from "../../dish/durable-object/dish-tables";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import { mealTables } from "../../meal/durable-object/meal-tables";

const estimationSchedules = sqliteTable(
  "estimation_schedules",
  {
    id: text("id").primaryKey(),
    dueAt: integer("due_at", { mode: "timestamp_ms" }).notNull(),
    countedOn: text("counted_on").notNull(),
  },
  (table) => [index("estimation_schedules_counted_on").on(table.countedOn)],
);

// 予定は食事を直に指さず、このつなぎで指す。食事を消すとつなぎだけが消える
const mealEstimationSchedules = sqliteTable(
  "meal_estimation_schedules",
  {
    estimationScheduleId: text("estimation_schedule_id")
      .primaryKey()
      .references(() => estimationSchedules.id),
    mealId: text("meal_id")
      .notNull()
      .references(() => mealTables.meals.id, { onDelete: "cascade" }),
  },
  (table) => [index("meal_estimation_schedules_meal_id").on(table.mealId)],
);

const estimationDeferrals = sqliteTable("estimation_deferrals", {
  estimationScheduleId: text("estimation_schedule_id")
    .primaryKey()
    .references(() => estimationSchedules.id),
  deferredAt: integer("deferred_at", { mode: "timestamp_ms" }).notNull(),
});

const estimations = sqliteTable(
  "estimations",
  {
    id: text("id").primaryKey(),
    estimationScheduleId: text("estimation_schedule_id")
      .notNull()
      .references(() => estimationSchedules.id),
    startedAt: integer("started_at", { mode: "timestamp_ms" }).notNull(),
  },
  (table) => [uniqueIndex("estimations_estimation_schedule_id").on(table.estimationScheduleId)],
);

const estimationAttempts = sqliteTable(
  "estimation_attempts",
  {
    id: text("id").primaryKey(),
    estimationId: text("estimation_id")
      .notNull()
      .references(() => estimations.id),
    attemptedAt: integer("attempted_at", { mode: "timestamp_ms" }).notNull(),
  },
  (table) => [index("estimation_attempts_estimation_id").on(table.estimationId, table.attemptedAt)],
);

const estimationAttemptResults = sqliteTable("estimation_attempt_results", {
  estimationAttemptId: text("estimation_attempt_id")
    .primaryKey()
    .references(() => estimationAttempts.id),
  endedAt: integer("ended_at", { mode: "timestamp_ms" }).notNull(),
  result: text("result", {
    enum: ["succeeded", "provider_error", "timed_out", "bad_request", "invalid_response"],
  }).notNull(),
});

// 提供元が返したエラーの種類。提供元の文字列なので enum にしない
const estimationAttemptErrors = sqliteTable("estimation_attempt_errors", {
  estimationAttemptId: text("estimation_attempt_id")
    .primaryKey()
    .references(() => estimationAttemptResults.estimationAttemptId),
  errorType: text("error_type").notNull(),
});

const estimationCompletions = sqliteTable("estimation_completions", {
  estimationId: text("estimation_id")
    .primaryKey()
    .references(() => estimations.id),
  completedAt: integer("completed_at", { mode: "timestamp_ms" }).notNull(),
  result: text("result", { enum: ["estimated", "no_dishes"] }).notNull(),
});

const estimationAbandonments = sqliteTable("estimation_abandonments", {
  estimationId: text("estimation_id")
    .primaryKey()
    .references(() => estimations.id),
  abandonedAt: integer("abandoned_at", { mode: "timestamp_ms" }).notNull(),
});

// 料理が対象の予定の取り消し。控えは取り消した名前の修正の書き込み（UNIQUE にしない理由は #332 の Schema changes）
const estimationScheduleCancellations = sqliteTable("estimation_schedule_cancellations", {
  // 料理の表がこの表の束を指し返すので、型の推論が循環しないよう参照先の型を書く
  estimationScheduleId: text("estimation_schedule_id")
    .primaryKey()
    .references((): AnySQLiteColumn => dishTables.dishEstimationSchedules.estimationScheduleId, {
      onDelete: "cascade",
    }),
  syncWriteReceiptId: text("sync_write_receipt_id")
    .notNull()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
});

// 推定の出来事の表（予定・推定・見送り・試み・結果・完了・断念・取り消し）。INSERT だけで持つ。宣言は durable-object-migrations/ の SQL に合わせる
export const estimationTables = {
  estimationSchedules,
  mealEstimationSchedules,
  estimationDeferrals,
  estimations,
  estimationAttempts,
  estimationAttemptResults,
  estimationAttemptErrors,
  estimationCompletions,
  estimationAbandonments,
  estimationScheduleCancellations,
};
