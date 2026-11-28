import { addDays } from "../../../domain/add-days";
import { daysPerWeek } from "../../../domain/days-per-week";

// 見直す月曜 M の、見直す入力の週（M の前の月〜日、YYYY-MM-DD）
export const computeReviewWeekRange = (
  reviewedMonday: string,
): { weekStart: string; weekEnd: string } => ({
  weekStart: addDays(reviewedMonday, -daysPerWeek),
  weekEnd: addDays(reviewedMonday, -1),
});
