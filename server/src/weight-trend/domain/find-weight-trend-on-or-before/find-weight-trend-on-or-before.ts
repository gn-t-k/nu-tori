import type { WeightTrend } from "../weight-trend";

// ある日の体重の傾向。体重の傾向は最後の体重記録の日で終わるので、その日以前で最も新しい日の値を使う。
// その日以前に体重記録が無ければ無い
export const findWeightTrendOnOrBefore = (
  trend: WeightTrend,
  calendarDay: string,
): WeightTrend[number] | undefined => trend.findLast((entry) => entry.calendarDay <= calendarDay);
