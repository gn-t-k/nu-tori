import { integer, primaryKey, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { expenditureEstimateTables } from "../../expenditure-estimate/durable-object/expenditure-estimate-tables";
import { goalTables } from "../../goal/durable-object/goal-tables";
import { dailyGuideLimitTypes, dailyGuideMainReasons } from "../domain/daily-guide";

// 1日の目安。目標と当てる始まりの日に1行。立てた・立て直したときの行は、当てる始まりの日が目標の開始の日のもの
const dailyGuides = sqliteTable(
  "daily_guides",
  {
    id: text("id").$type<RecordId>().primaryKey(),
    goalId: text("goal_id")
      .$type<RecordId>()
      .notNull()
      .references(() => goalTables.goals.id),
    expenditureEstimateId: text("expenditure_estimate_id")
      .$type<RecordId>()
      .notNull()
      .references(() => expenditureEstimateTables.expenditureEstimates.id),
    effectiveOn: text("effective_on").notNull(),
    energyKcal: integer("energy_kcal").notNull(),
    proteinG: integer("protein_g").notNull(),
    fatG: integer("fat_g").notNull(),
    carbohydrateG: integer("carbohydrate_g").notNull(),
  },
  (table) => [uniqueIndex("daily_guides_goal_id").on(table.goalId, table.effectiveOn)],
);

// 当たった上限と下限。当たったものだけの行
const dailyGuideLimitHits = sqliteTable(
  "daily_guide_limit_hits",
  {
    dailyGuideId: text("daily_guide_id")
      .$type<RecordId>()
      .notNull()
      .references(() => dailyGuides.id),
    limitType: text("limit_type", { enum: dailyGuideLimitTypes }).notNull(),
  },
  (table) => [primaryKey({ columns: [table.dailyGuideId, table.limitType] })],
);

// 週の見直しが書いた1日の目安（#613）。見直しは指さず、同じ見直しが書いた推定を通してたどる
const reviewedDailyGuides = sqliteTable("reviewed_daily_guides", {
  dailyGuideId: text("daily_guide_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => dailyGuides.id),
  mainReason: text("main_reason", { enum: dailyGuideMainReasons }).notNull(),
});

// 1日の目安の表（#523・#613）。どの表も書き足すだけ。宣言は durable-object-migrations/ の SQL に合わせる
export const dailyGuideTables = {
  dailyGuides,
  dailyGuideLimitHits,
  reviewedDailyGuides,
};
