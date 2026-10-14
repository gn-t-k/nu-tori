import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { initialExpenditureSources } from "../domain/expenditure-estimate";

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

// 推定消費カロリーの表（#523）。どの表も書き足すだけ。宣言は durable-object-migrations/ の SQL に合わせる
export const expenditureEstimateTables = {
  expenditureEstimates,
  initialExpenditureEstimates,
};
