import { addDays } from "../../domain/add-days";
import { excludePartiallyRecordedDays } from "../../expenditure-estimate/domain/exclude-partially-recorded-days";
import { computeReviewWeekRange } from "./compute-review-week-range";

// 見直す月曜 M の入力の週の、食事を記録した日（部分的な記録の日を外す）。
// recordedEnergyIntakes は、nu-tori の記録から出した日ごとの食べた量で、M より前の 28 日を含む
export const findRecordedMealDays = (
  reviewedMonday: string,
  recordedEnergyIntakes: readonly RecordedEnergyIntake[],
): RecordedEnergyIntake[] => {
  const { weekEnd, isInWeek } = computeReviewWeekRange(reviewedMonday);
  const windowStart = addDays(reviewedMonday, -partialDayWindowDays);
  return excludePartiallyRecordedDays(
    recordedEnergyIntakes.filter(
      ({ calendarDay }) => windowStart <= calendarDay && calendarDay <= weekEnd,
    ),
  ).filter(({ calendarDay }) => isInWeek(calendarDay));
};

type RecordedEnergyIntake = { calendarDay: string; kcal: number };

// 部分的な記録の日を決める中央値を出す日数（M より前）
const partialDayWindowDays = 28;
