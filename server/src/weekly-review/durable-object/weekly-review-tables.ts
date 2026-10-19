import { integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { goalTables } from "../../goal/durable-object/goal-tables";
import { weeklyReviewDeferralReasons } from "../domain/weekly-review";

// 週の見直し（見送りを含む）。1週に1行
const weeklyReviews = sqliteTable(
  "weekly_reviews",
  {
    id: text("id").$type<RecordId>().primaryKey(),
    effectiveOn: text("effective_on").notNull(),
    reviewedAt: integer("reviewed_at", { mode: "timestamp_ms" }).notNull(),
    timeZone: text("time_zone").notNull(),
  },
  (table) => [uniqueIndex("weekly_reviews_effective_on").on(table.effectiveOn)],
);

// 見送った週のサブセット。goal_id はその週に当てた目標
const deferredWeeklyReviews = sqliteTable("deferred_weekly_reviews", {
  weeklyReviewId: text("weekly_review_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => weeklyReviews.id),
  goalId: text("goal_id")
    .$type<RecordId>()
    .notNull()
    .references(() => goalTables.goals.id),
  reason: text("reason", { enum: weeklyReviewDeferralReasons }).notNull(),
});

// 週の見直しの表（#613）。どの表も書き足すだけ。宣言は durable-object-migrations/ の SQL に合わせる。
// 見直した推定と見直した1日の目安は、推定消費カロリーと1日の目安の表の束に置く
export const weeklyReviewTables = {
  weeklyReviews,
  deferredWeeklyReviews,
};
