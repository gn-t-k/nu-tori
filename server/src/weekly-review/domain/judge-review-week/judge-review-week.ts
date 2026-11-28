import { addDays } from "../../../domain/add-days";
import { countDaysBetween } from "../../../domain/count-days-between";
import type { InitialExpenditureSource } from "../../../expenditure-estimate/domain/expenditure-estimate";
import { computeWeightTrend } from "../../../weight-trend/domain/compute-weight-trend";
import type { WeeklyReviewDeferralReason } from "../weekly-review";
import { daysPerWeek } from "../../../domain/days-per-week";
import { computeObservedExpenditure } from "../compute-observed-expenditure";
import { computeReviewWeekRange } from "../compute-review-week-range";
import { findRecordedMealDays } from "../find-recorded-meal-days";
import { minimumMealDays } from "../minimum-meal-days";

export type ReviewWeekInputs = {
  // 見直す月曜 M（YYYY-MM-DD）。見直す入力の週は M の前の月〜日
  reviewedMonday: string;
  // 使い始めた日。読めない人には undefined
  startedUsingOn: string | undefined;
  // 推定の始まりの出どころ。推定の始まりが読めなければ undefined（逆算ではないとみなす）
  initialExpenditureSource: InitialExpenditureSource | undefined;
  // 推定の始まりの推定消費カロリー（kcal）。読めなければ undefined（量では見送らない）
  initialExpenditureKcal: number | undefined;
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
      // 実際の変化。終わりの日の体重の傾向 − 始まりの日の体重の傾向（日は computeWeightChange）
      actualWeightChangeKg: number;
      // 実際の変化を測った日数（始まりの日から終わりの日まで）。7 日とは限らない
      weightChangeDayCount: number;
      // M の前の日曜の体重の傾向。1日の目安の必要な速さを出す元
      sundayWeightTrendKg: number;
    };

// 見直す週を見送るかを決める。当たる理由が2つ以上あれば、使い始めて7日未満、体重が無い、食事の記録が少ないの順で最初の1つを返す
export const judgeReviewWeek = ({
  reviewedMonday,
  startedUsingOn,
  initialExpenditureSource,
  initialExpenditureKcal,
  dailyWeights,
  recordedEnergyIntakes,
}: ReviewWeekInputs): ReviewWeekJudgement => {
  const { weekStart, weekEnd, isInWeek } = computeReviewWeekRange(reviewedMonday);

  // 使い始める前の記録から逆算した人は、使い始める前の記録で初期値が確かなので当てない。
  // 使い始めた日が読めない人は、7日未満とみなす元が無いので当てない
  if (
    initialExpenditureSource !== "back_calculated" &&
    startedUsingOn !== undefined &&
    countDaysBetween(startedUsingOn, reviewedMonday) < daysPerWeek
  ) {
    return { type: "deferred", reason: "within_first_week" };
  }

  const weightChange = dailyWeights.some(({ calendarDay }) => isInWeek(calendarDay))
    ? computeWeightChange(dailyWeights, { weekStart, weekEnd })
    : undefined;
  if (weightChange === undefined) {
    return { type: "deferred", reason: "no_weight" };
  }

  const mealDays = findRecordedMealDays(reviewedMonday, recordedEnergyIntakes);
  if (mealDays.length < minimumMealDays) {
    return { type: "deferred", reason: "few_meal_records" };
  }

  const averageEnergyIntakeKcal =
    mealDays.reduce((sum, { kcal }) => sum + kcal, 0) / mealDays.length;
  // 記録が意味する消費が推定の始まりの 0.6 倍（おおよそ基礎代謝の 0.7 倍）に満たない週は、体がそれだけしか使わないことはありえないので、記録の抜けとみなして見送る。
  // 部分的な記録の日の除外は毎日同じように少なく記録すると効かず、記録した日数の決まりは量を見ないため。
  // 見送りの理由を足すと端末の表示の分かれが増えるので、記録が少ない週として見送る
  const observedExpenditureKcal = computeObservedExpenditure({
    averageEnergyIntakeKcal,
    actualWeightChangeKg: weightChange.actualWeightChangeKg,
    weightChangeDayCount: weightChange.weightChangeDayCount,
  });
  if (
    initialExpenditureKcal !== undefined &&
    observedExpenditureKcal < minimumObservedExpenditureRatio * initialExpenditureKcal
  ) {
    return { type: "deferred", reason: "few_meal_records" };
  }

  return {
    type: "reviewable",
    averageEnergyIntakeKcal,
    recordedMealDayCount: mealDays.length,
    ...weightChange,
  };
};

// 実際の変化は、始まりと終わりをどちらも「その日曜までで最後に体重を記録した日」の体重の傾向で測る。
// 体重の傾向は最後の体重記録の日で終わり、記録の無い日の値は次の記録が来て決まる。
// 日曜の値で測ると、見直しの時点で日曜より後の記録があるかで終わりの日が変わり、次の週の始まりとのあいだの変化がどの週にも入らない。
// 記録のある日の値はあとの記録で変わらないので、前の週の終わりと次の週の始まりが同じ日になる。
// 前の週に記録が無ければ（前の週は体重が無いで見送った）その前の日曜の値から、それも無ければ入力の週の月曜の値から測る。
// 始まりが無いか、始まりと終わりが同じ日なら、変化を出せない（undefined）
const computeWeightChange = (
  dailyWeights: ReviewWeekInputs["dailyWeights"],
  { weekStart, weekEnd }: { weekStart: string; weekEnd: string },
):
  | { actualWeightChangeKg: number; weightChangeDayCount: number; sundayWeightTrendKg: number }
  | undefined => {
  const trend = computeWeightTrend(dailyWeights);
  const trendOn = (calendarDay: string) => trend.find((point) => point.calendarDay === calendarDay);
  const lastWeighedOn = (lastDay: string) =>
    dailyWeights.findLast(({ calendarDay }) => calendarDay <= lastDay)?.calendarDay;
  const previousSunday = addDays(weekStart, -1);
  const previousWeekLastWeighedOn = lastWeighedOn(previousSunday);
  const start =
    previousWeekLastWeighedOn !== undefined &&
    addDays(weekStart, -daysPerWeek) <= previousWeekLastWeighedOn
      ? trendOn(previousWeekLastWeighedOn)
      : (trendOn(previousSunday) ?? trendOn(weekStart));
  const weekLastWeighedOn = lastWeighedOn(weekEnd);
  const end = weekLastWeighedOn === undefined ? undefined : trendOn(weekLastWeighedOn);
  // 1日の目安の元は、測り方と別に、日曜の時点でいちばん新しい体重の傾向にする
  const sundayTrend = trend.findLast(({ calendarDay }) => calendarDay <= weekEnd);
  if (start === undefined || end === undefined || sundayTrend === undefined) {
    return undefined;
  }
  const weightChangeDayCount = countDaysBetween(start.calendarDay, end.calendarDay);
  return weightChangeDayCount === 0
    ? undefined
    : {
        actualWeightChangeKg: end.trendKg - start.trendKg,
        weightChangeDayCount,
        sundayWeightTrendKg: sundayTrend.trendKg,
      };
};

// 記録が意味する消費が、推定の始まりのこの割合に満たない週を見送る。出荷後に実データで調整する初期値
const minimumObservedExpenditureRatio = 0.6;
