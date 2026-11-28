import { findRecordedMealDays } from "../find-recorded-meal-days";
import { minimumMealDays } from "../minimum-meal-days";

// 前に見直せた週の、食事を記録した日数（推定の不確かさをたどり直すのに使う）。今の記録で数え直す。
// 見直したあとに食事を消して少なくなっても、見直せた週は見送らない日数があったので、見送らない最小の日数を下限にする
export const countReviewedWeekMealDays = (
  reviewedMonday: string,
  recordedEnergyIntakes: readonly { calendarDay: string; kcal: number }[],
): number =>
  Math.max(findRecordedMealDays(reviewedMonday, recordedEnergyIntakes).length, minimumMealDays);
