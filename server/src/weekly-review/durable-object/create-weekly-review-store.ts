import { desc, eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { dailyGuideTables } from "../../daily-guide/durable-object/daily-guide-tables";
import type { RecordId } from "../../domain/record-id";
import { expenditureEstimateTables } from "../../expenditure-estimate/durable-object/expenditure-estimate-tables";
import type { WeeklyReview } from "../domain/weekly-review";
import type { WeeklyReviewStore } from "../domain/weekly-review-store";
import { weeklyReviewTables } from "./weekly-review-tables";

const { weeklyReviews, deferredWeeklyReviews } = weeklyReviewTables;
const { reviewedExpenditureEstimates } = expenditureEstimateTables;
const { dailyGuides, reviewedDailyGuides } = dailyGuideTables;

export const createWeeklyReviewStore = (db: DrizzleSqliteDODatabase): WeeklyReviewStore => {
  const find = (id: RecordId): WeeklyReview | undefined => {
    const review = db.select().from(weeklyReviews).where(eq(weeklyReviews.id, id)).get();
    if (review === undefined) {
      return undefined;
    }
    const deferral = db
      .select({ reason: deferredWeeklyReviews.reason, goalId: deferredWeeklyReviews.goalId })
      .from(deferredWeeklyReviews)
      .where(eq(deferredWeeklyReviews.weeklyReviewId, id))
      .get();
    if (deferral !== undefined) {
      return { ...review, outcome: { type: "deferred", ...deferral } };
    }
    // 見直した1日の目安は見直しを指さないので、同じ見直しが書いた推定からたどる。
    // 同じ推定を指す1日の目安には、見送った週に期限後の維持へ移って写した行もあるので、見直した1日の目安の行で絞る
    const result = db
      .select({
        expenditureEstimateId: reviewedExpenditureEstimates.expenditureEstimateId,
        dailyGuideId: dailyGuides.id,
        mainReason: reviewedDailyGuides.mainReason,
      })
      .from(reviewedExpenditureEstimates)
      .innerJoin(
        dailyGuides,
        eq(dailyGuides.expenditureEstimateId, reviewedExpenditureEstimates.expenditureEstimateId),
      )
      .innerJoin(reviewedDailyGuides, eq(reviewedDailyGuides.dailyGuideId, dailyGuides.id))
      .where(eq(reviewedExpenditureEstimates.weeklyReviewId, id))
      .get();
    if (result === undefined) {
      // 書く口が、見送りか、見直した推定と見直した1日の目安を、同じトランザクションで書く。どちらも無いのは不具合
      throw new Error(`見送りも見直しも無い週の見直し: ${id}`);
    }
    return { ...review, outcome: { type: "reviewed", ...result } };
  };
  return {
    find,
    findLatest: () => {
      const latest = db
        .select({ id: weeklyReviews.id })
        .from(weeklyReviews)
        .orderBy(desc(weeklyReviews.effectiveOn))
        .limit(1)
        .get();
      return latest === undefined ? undefined : find(latest.id);
    },
    insert: (review) => {
      db.insert(weeklyReviews).values(review).run();
    },
    insertDeferral: (deferral) => {
      db.insert(deferredWeeklyReviews).values(deferral).run();
    },
  };
};
