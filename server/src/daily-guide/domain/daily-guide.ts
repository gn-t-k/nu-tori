import type { RecordId } from "../../domain/record-id";

// 1日の目安。ID はサーバーが振る
export type DailyGuide = {
  id: RecordId;
  goalId: RecordId;
  // 計算に使った推定消費カロリーの推定
  expenditureEstimateId: RecordId;
  // 当てる始まりの日（YYYY-MM-DD）
  effectiveOn: string;
  energyKcal: number;
  proteinG: number;
  fatG: number;
  carbohydrateG: number;
  // 当たった上限と下限。当たったものだけを、dailyGuideLimitTypes の順に並べる
  limitHits: DailyGuideLimitType[];
};

// 1日の目安を出すときに値を抑える決まり。1週の変化、必要な速さの上限、下限のエネルギー
export const dailyGuideLimitTypes = ["weekly_change", "required_pace", "minimum_energy"] as const;

export type DailyGuideLimitType = (typeof dailyGuideLimitTypes)[number];
