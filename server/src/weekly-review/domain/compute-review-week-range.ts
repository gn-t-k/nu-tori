import { addDays } from "../../domain/add-days";
import { daysPerWeek } from "../../domain/days-per-week";

// 見直す月曜 M の、見直す入力の週（M の前の月〜日、YYYY-MM-DD）と、日がその週に入るかの判定
export const computeReviewWeekRange = (
  reviewedMonday: string,
): { weekStart: string; weekEnd: string; isInWeek: (calendarDay: string) => boolean } => {
  const weekStart = addDays(reviewedMonday, -daysPerWeek);
  const weekEnd = addDays(reviewedMonday, -1);
  return {
    weekStart,
    weekEnd,
    isInWeek: (calendarDay) => weekStart <= calendarDay && calendarDay <= weekEnd,
  };
};
