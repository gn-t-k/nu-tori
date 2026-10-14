import type { DailyGuideLimitType } from "./daily-guide";
import type { DailyGuideAmounts } from "./daily-guide-amounts";

// 目標を立てた・立て直したときに計算した1日の目安。記録にする前なので ID と始まりの日を持たない。
// 前の週からの変化を抑えるのは見直しだけなので、1週の変化には当たらない
export type ComputedDailyGuide = DailyGuideAmounts & {
  limitHits: Exclude<DailyGuideLimitType, "weekly_change">[];
};
