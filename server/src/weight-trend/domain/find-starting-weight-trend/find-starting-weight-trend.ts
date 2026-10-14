import type { WeightTrend } from "../weight-trend";

// 開始の日の体重の傾向。体重の傾向は最後の体重記録の日で終わるので、開始の日以前で最も新しい日の値を使う
export const findStartingWeightTrend = (
  trend: WeightTrend,
  startDay: string,
): WeightTrend[number] | undefined => trend.findLast(({ calendarDay }) => calendarDay <= startDay);
