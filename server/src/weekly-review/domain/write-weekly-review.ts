import type { ComputedReviewedDailyGuide } from "../../daily-guide/domain/computed-daily-guide";
import { dailyGuideLimitTypes, dailyGuideMainReasons } from "../../daily-guide/domain/daily-guide";
import { computeDayOfWeek } from "../../domain/compute-day-of-week";
import type { RecordChangeWrites } from "../../domain/record-change-writes";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import {
  type ExpenditureDeviationDirection,
  expenditureDeviationDirections,
} from "../../expenditure-estimate/domain/expenditure-estimate";
import {
  type WeeklyReview,
  type WeeklyReviewDeferral,
  weeklyReviewDeferralReasons,
} from "./weekly-review";

// 書く週の見直し。見送った週は見送りを、見直せた週は新しい推定と、それを使った今の目標の1日の目安を持つ
export type WeeklyReviewToWrite = Omit<WeeklyReview, "id" | "outcome"> & {
  outcome:
    | WeeklyReviewDeferral
    | {
        type: "reviewed";
        expenditure: {
          expenditureKcal: number;
          deviationDirection: ExpenditureDeviationDirection;
        };
        dailyGuide: ComputedReviewedDailyGuide & { goalId: RecordId };
      };
};

// 週の見直しを書く口。週の見直しと、見送りか見直した推定と1日の目安の行を、外部キーが指す行を先にして書き、
// 変えた記録を、依る記録を先にして足す（推定消費カロリー → 1日の目安 → 週の見直し）。
// 記録の変化を書く入口（RecordChangeWriter）の run の中で、1週に1回呼ぶ。
// 見直した推定の当てる始まりの日と推定した時刻は、週の見直しの月曜と見直した時刻にし、見直した1日の目安はその推定を指してその月曜から当てる。
// 表で守らない決まり（当てる日は最も遅い推定より後の月曜、見送りと1日の目安は今の目標を指す、区分の値）は、書く前にここで確かめて投げる。
// 1週に1つは一意の索引が保つ
export const writeWeeklyReview = (
  stores: Pick<RecordKindStores, "weeklyReview" | "goal" | "expenditureEstimate" | "dailyGuide">,
  addChange: RecordChangeWrites["addChange"],
  review: WeeklyReviewToWrite,
): RecordId => {
  const { outcome, ...weeklyReview } = review;
  requireWritable(stores, review);

  const id = generateRecordId();
  stores.weeklyReview.insert({ ...weeklyReview, id });
  if (outcome.type === "deferred") {
    stores.weeklyReview.insertDeferral({
      weeklyReviewId: id,
      reason: outcome.reason,
      goalId: outcome.goalId,
    });
    addChange({ recordType: "weekly_review", recordId: id });
    return id;
  }

  const expenditureEstimateId = generateRecordId();
  const dailyGuideId = generateRecordId();
  const { mainReason, ...dailyGuide } = outcome.dailyGuide;
  stores.expenditureEstimate.insert({
    id: expenditureEstimateId,
    effectiveOn: review.effectiveOn,
    expenditureKcal: outcome.expenditure.expenditureKcal,
    estimatedAt: review.reviewedAt,
    initialSource: undefined,
  });
  stores.weeklyReview.insertReviewedExpenditureEstimate({
    expenditureEstimateId,
    weeklyReviewId: id,
    deviationDirection: outcome.expenditure.deviationDirection,
  });
  stores.dailyGuide.insert({
    ...dailyGuide,
    id: dailyGuideId,
    expenditureEstimateId,
    effectiveOn: review.effectiveOn,
  });
  stores.weeklyReview.insertReviewedDailyGuide({ dailyGuideId, mainReason });

  addChange({ recordType: "expenditure_estimate", recordId: expenditureEstimateId });
  addChange({ recordType: "daily_guide", recordId: dailyGuideId });
  addChange({ recordType: "weekly_review", recordId: id });
  return id;
};

const requireWritable = (
  stores: Pick<RecordKindStores, "goal" | "expenditureEstimate">,
  { effectiveOn, outcome }: WeeklyReviewToWrite,
): void => {
  if (computeDayOfWeek(effectiveOn) !== "monday") {
    throw new Error("見直しの当てる日が月曜でない");
  }
  const latestEstimate = stores.expenditureEstimate.findCurrent();
  if (latestEstimate !== undefined && effectiveOn <= latestEstimate.effectiveOn) {
    throw new Error("見直す月曜が、最も遅い推定の当てる始まりの日より後でない");
  }
  const goalId = outcome.type === "deferred" ? outcome.goalId : outcome.dailyGuide.goalId;
  if (goalId !== stores.goal.findCurrent()?.id) {
    throw new Error("見直しの目標が、今の目標ではない");
  }
  // 区分の列に CHECK は無いので、型をすり抜けた値をここで止める
  if (outcome.type === "deferred") {
    if (!isListed(weeklyReviewDeferralReasons, outcome.reason)) {
      throw new Error("見送りの理由の値が一覧に無い");
    }
    return;
  }
  if (!isListed(expenditureDeviationDirections, outcome.expenditure.deviationDirection)) {
    throw new Error("ずれの向きの値が一覧に無い");
  }
  if (!isListed(dailyGuideMainReasons, outcome.dailyGuide.mainReason)) {
    throw new Error("主な理由の値が一覧に無い");
  }
  if (
    !outcome.dailyGuide.limitHits.every((limitType) => isListed(dailyGuideLimitTypes, limitType))
  ) {
    throw new Error("当たった上限と下限の値が一覧に無い");
  }
};

const isListed = (values: readonly string[], value: string): boolean => values.includes(value);
