import type { RecordId } from "../../domain/record-id";
import type { DailyGuideMainReason } from "../../daily-guide/domain/daily-guide";

// 週の見直し。見送った週も1つ持つ。ID はサーバーが振る
export type WeeklyReview = {
  id: RecordId;
  // 新しい1日の目安を当てる月曜（YYYY-MM-DD）。見直す入力の月〜日はその前の週
  effectiveOn: string;
  reviewedAt: Date;
  // 見直しを起こした要求のタイムゾーン
  timeZone: string;
  // 見送ったか見直せたかのどちらか一方
  outcome: WeeklyReviewDeferral | WeeklyReviewResult;
};

// 見送った週
export type WeeklyReviewDeferral = {
  type: "deferred";
  reason: WeeklyReviewDeferralReason;
  // その週に当てた目標
  goalId: RecordId;
};

// 見直せた週。見直した推定と、その推定を使った見直した1日の目安
export type WeeklyReviewResult = {
  type: "reviewed";
  expenditureEstimateId: RecordId;
  dailyGuideId: RecordId;
  mainReason: DailyGuideMainReason;
};

// 見送りの理由。使い始めて1週に満たない、体重が無い、食事の記録が少ない。
// 2つ以上当たる週は、この順で先のものを1つ残す
export const weeklyReviewDeferralReasons = [
  "within_first_week",
  "no_weight",
  "few_meal_records",
] as const;

export type WeeklyReviewDeferralReason = (typeof weeklyReviewDeferralReasons)[number];
