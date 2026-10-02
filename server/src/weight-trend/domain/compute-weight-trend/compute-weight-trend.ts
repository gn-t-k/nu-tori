import { addDays } from "../../../domain/add-days";
import { millisecondsPerDay } from "../../../domain/milliseconds-per-day";
import type { WeightTrend } from "../weight-trend";

// 日の代表値を日の順に受け取る。無い日を線形に埋めてから、指数移動平均でならす
export const computeWeightTrend = (
  dailyWeights: readonly { calendarDay: string; weightKg: number }[],
): WeightTrend => {
  const smoothingWeight = 0.1;
  const trend: { calendarDay: string; trendKg: number }[] = [];
  for (const { calendarDay, weightKg } of fillMissingDays(dailyWeights)) {
    const previous = trend.at(-1);
    trend.push({
      calendarDay,
      trendKg:
        previous === undefined
          ? weightKg
          : previous.trendKg + smoothingWeight * (weightKg - previous.trendKg),
    });
  }
  return trend;
};

const fillMissingDays = (
  dailyWeights: readonly { calendarDay: string; weightKg: number }[],
): { calendarDay: string; weightKg: number }[] =>
  dailyWeights.flatMap((current, index) => {
    const next = dailyWeights[index + 1];
    if (next === undefined) {
      return [current];
    }
    const days = daysBetween(current.calendarDay, next.calendarDay);
    return Array.from({ length: days }, (_, offset) => ({
      calendarDay: addDays(current.calendarDay, offset),
      weightKg: current.weightKg + ((next.weightKg - current.weightKg) * offset) / days,
    }));
  });

const daysBetween = (from: string, to: string): number =>
  Math.round(
    (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / millisecondsPerDay,
  );
