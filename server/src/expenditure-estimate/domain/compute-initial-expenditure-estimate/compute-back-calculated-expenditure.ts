import { countDaysBetween } from "../../../domain/count-days-between";
import { kilocaloriesPerKilogram } from "../../../domain/kilocalories-per-kilogram";
import { excludePartiallyRecordedDays } from "../exclude-partially-recorded-days";

// 初期値の窓の中の食べた量と日の代表値を受け取る。記録が足りなければ undefined。値は丸めない
export const computeBackCalculatedExpenditure = (
  energyIntakes: readonly { calendarDay: string; kcal: number }[],
  dailyWeights: readonly { calendarDay: string; weightKg: number }[],
): number | undefined => {
  const minimumIntakeDays = 14;
  const intakeDays = excludePartiallyRecordedDays(energyIntakes);
  if (intakeDays.length < minimumIntakeDays) {
    return undefined;
  }
  const slope = computeWeightSlope(dailyWeights);
  if (slope === undefined) {
    return undefined;
  }
  const averageIntake = intakeDays.reduce((sum, { kcal }) => sum + kcal, 0) / intakeDays.length;
  return averageIntake - kilocaloriesPerKilogram * slope;
};

// 日の代表値に最小二乗で当てた直線の傾き（kg/日）。点が少ないか、日の幅が狭いと、日々の揺れが傾きになるので出さない
const computeWeightSlope = (
  dailyWeights: readonly { calendarDay: string; weightKg: number }[],
): number | undefined => {
  const minimumWeightDays = 4;
  const minimumSpanDays = 14;
  const days = dailyWeights.map(({ calendarDay }) => calendarDay).toSorted();
  const firstDay = days.at(0);
  const lastDay = days.at(-1);
  if (
    firstDay === undefined ||
    lastDay === undefined ||
    days.length < minimumWeightDays ||
    countDaysBetween(firstDay, lastDay) < minimumSpanDays
  ) {
    return undefined;
  }
  const points = dailyWeights.map(({ calendarDay, weightKg }) => ({
    day: countDaysBetween(firstDay, calendarDay),
    weightKg,
  }));
  const meanDay = points.reduce((sum, { day }) => sum + day, 0) / points.length;
  const meanWeightKg = points.reduce((sum, { weightKg }) => sum + weightKg, 0) / points.length;
  const covariance = points.reduce(
    (sum, { day, weightKg }) => sum + (day - meanDay) * (weightKg - meanWeightKg),
    0,
  );
  const variance = points.reduce((sum, { day }) => sum + (day - meanDay) ** 2, 0);
  return covariance / variance;
};
