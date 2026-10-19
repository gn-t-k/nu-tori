import { integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { weeklyReviewTables } from "../../weekly-review/durable-object/weekly-review-tables";
import {
  expenditureDeviationDirections,
  initialExpenditureSources,
} from "../domain/expenditure-estimate";

const expenditureEstimates = sqliteTable("expenditure_estimates", {
  id: text("id").$type<RecordId>().primaryKey(),
  effectiveOn: text("effective_on").notNull(),
  expenditureKcal: integer("expenditure_kcal").notNull(),
  estimatedAt: integer("estimated_at", { mode: "timestamp_ms" }).notNull(),
});

// 推定の始まり。表全体で1行で、書く口が推定の行がまだ無いときだけ書いて保つ
const initialExpenditureEstimates = sqliteTable("initial_expenditure_estimates", {
  expenditureEstimateId: text("expenditure_estimate_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => expenditureEstimates.id),
  source: text("source", { enum: initialExpenditureSources }).notNull(),
});

// 週の見直しが書いた推定（#613）。1つの見直しに1行。ずれの向きは次の見直しで続いた週の数を数えるのに使う
const reviewedExpenditureEstimates = sqliteTable(
  "reviewed_expenditure_estimates",
  {
    expenditureEstimateId: text("expenditure_estimate_id")
      .$type<RecordId>()
      .primaryKey()
      .references(() => expenditureEstimates.id),
    weeklyReviewId: text("weekly_review_id")
      .$type<RecordId>()
      .notNull()
      .references(() => weeklyReviewTables.weeklyReviews.id),
    deviationDirection: text("deviation_direction", {
      enum: expenditureDeviationDirections,
    }).notNull(),
  },
  (table) => [
    uniqueIndex("reviewed_expenditure_estimates_weekly_review_id").on(table.weeklyReviewId),
  ],
);

// 推定消費カロリーの表（#523・#613）。どの表も書き足すだけ。宣言は durable-object-migrations/ の SQL に合わせる
export const expenditureEstimateTables = {
  expenditureEstimates,
  initialExpenditureEstimates,
  reviewedExpenditureEstimates,
};
