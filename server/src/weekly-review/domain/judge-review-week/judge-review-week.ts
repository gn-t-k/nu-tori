import { addDays } from "../../../domain/add-days";
import { countDaysBetween } from "../../../domain/count-days-between";
import { excludePartiallyRecordedDays } from "../../../expenditure-estimate/domain/exclude-partially-recorded-days";
import type { InitialExpenditureSource } from "../../../expenditure-estimate/domain/expenditure-estimate";
import { computeWeightTrend } from "../../../weight-trend/domain/compute-weight-trend";
import type { WeeklyReviewDeferralReason } from "../weekly-review";

export type ReviewWeekInputs = {
  // 見直す月曜 M（YYYY-MM-DD）。見直す入力の週は M の前の月〜日
  reviewedMonday: string;
  // 使い始めた日。読めない人には undefined
  startedUsingOn: string | undefined;
  // 推定の始まりの出どころ
  initialExpenditureSource: InitialExpenditureSource;
  // 日の代表値を日の順に
  dailyWeights: readonly { calendarDay: string; weightKg: number }[];
  // nu-tori の記録から出した、日ごとの食べた量。M より前の 28 日を含む
  recordedEnergyIntakes: readonly { calendarDay: string; kcal: number }[];
};

export type ReviewWeekJudgement =
  | { type: "deferred"; reason: WeeklyReviewDeferralReason }
  // 見直せる週と、見直しに使う値
  | {
      type: "reviewable";
      // 部分的な記録の日を外した、食事を記録した日の食べた量の平均
      averageEnergyIntakeKcal: number;
      recordedMealDayCount: number;
      // M の前の日曜の体重の傾向 − その前の日曜（無ければ入力の週の月曜）の体重の傾向
      actualWeightChangeKg: number;
    };

// 見直す週を見送るかを決める。当たる理由が2つ以上あれば、使い始めて7日未満、体重が無い、食事の記録が少ないの順で最初の1つを返す
export const judgeReviewWeek = ({
  reviewedMonday,
  startedUsingOn,
  initialExpenditureSource,
  dailyWeights,
  recordedEnergyIntakes,
}: ReviewWeekInputs): ReviewWeekJudgement => {
  const weekStart = addDays(reviewedMonday, -daysPerWeek);
  const weekEnd = addDays(reviewedMonday, -1);
  const isInWeek = (calendarDay: string) => weekStart <= calendarDay && calendarDay <= weekEnd;

  // 使い始める前の記録から逆算した人は、使い始める前の記録で初期値が確かなので当てない。
  // 使い始めた日が読めない人は、7日未満とみなす元が無いので当てない
  if (
    initialExpenditureSource !== "back_calculated" &&
    startedUsingOn !== undefined &&
    countDaysBetween(startedUsingOn, reviewedMonday) < daysPerWeek
  ) {
    return { type: "deferred", reason: "within_first_week" };
  }

  const actualWeightChangeKg = dailyWeights.some(({ calendarDay }) => isInWeek(calendarDay))
    ? computeActualWeightChangeKg(dailyWeights, { weekStart, weekEnd })
    : undefined;
  if (actualWeightChangeKg === undefined) {
    return { type: "deferred", reason: "no_weight" };
  }

  const windowStart = addDays(reviewedMonday, -partialDayWindowDays);
  const mealDays = excludePartiallyRecordedDays(
    recordedEnergyIntakes.filter(
      ({ calendarDay }) => windowStart <= calendarDay && calendarDay <= weekEnd,
    ),
  ).filter(({ calendarDay }) => isInWeek(calendarDay));
  if (mealDays.length < minimumMealDays) {
    return { type: "deferred", reason: "few_meal_records" };
  }

  return {
    type: "reviewable",
    averageEnergyIntakeKcal: mealDays.reduce((sum, { kcal }) => sum + kcal, 0) / mealDays.length,
    recordedMealDayCount: mealDays.length,
    actualWeightChangeKg,
  };
};

// 体重の傾向は最後の体重記録の日で終わるので、日曜の値はその日以前で最も新しい値を使う。
// その前の日曜にまだ傾向が無ければ入力の週の月曜の値を使い、月曜にも無ければ出せない（undefined）
const computeActualWeightChangeKg = (
  dailyWeights: ReviewWeekInputs["dailyWeights"],
  { weekStart, weekEnd }: { weekStart: string; weekEnd: string },
): number | undefined => {
  const trend = computeWeightTrend(dailyWeights);
  const previousSunday = addDays(weekStart, -1);
  const start =
    trend.findLast(({ calendarDay }) => calendarDay <= previousSunday) ??
    trend.find(({ calendarDay }) => calendarDay === weekStart);
  const end = trend.findLast(({ calendarDay }) => calendarDay <= weekEnd);
  return start === undefined || end === undefined ? undefined : end.trendKg - start.trendKg;
};

const daysPerWeek = 7;

// 部分的な記録の日を決める中央値を出す日数（M より前）
const partialDayWindowDays = 28;

const minimumMealDays = 4;
