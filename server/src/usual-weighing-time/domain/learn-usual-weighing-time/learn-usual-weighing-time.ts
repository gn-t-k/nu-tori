import { addDays } from "../../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../../domain/compute-calendar-day-in-time-zone";
import { computeUtcOffsetSeconds } from "../../../domain/compute-utc-offset-seconds";
import { millisecondsPerDay } from "../../../domain/milliseconds-per-day";
import { computeDailyRepresentativeWeights } from "../../../weight-record/domain/compute-daily-representative-weights";

// 体重記録から、いつもの時刻（その日の何分目）を学ぶ。範囲の中で記録のある日が3日そろわなければ undefined。
// 範囲は、timeZone での now の日（基準の今日）とその前の 27 日。timeZone は isTimeZoneName で確かめた IANA 名を渡す
export const learnUsualWeighingTime = (input: {
  weightRecords: readonly { id: string; measuredAt: Date; timeZone: string }[];
  now: Date;
  timeZone: string;
}): number | undefined => {
  const today = computeCalendarDayInTimeZone(input.now, input.timeZone);
  const firstDay = addDays(today, -(usualWeighingTimeRangeDays - 1));
  const minutes = computeDailyRepresentativeWeights(input.weightRecords)
    .filter(({ calendarDay }) => firstDay <= calendarDay && calendarDay <= today)
    .map(({ weightRecord }) => computeMinuteOfDay(weightRecord.measuredAt, weightRecord.timeZone))
    .toSorted((a, b) => a - b);
  if (minutes.length < minimumDays) {
    return undefined;
  }
  return roundToStep(computeMedian(minutes));
};

// 学ぶ範囲の日数（基準の今日を含む）
export const usualWeighingTimeRangeDays = 28;

const minimumDays = 3;
const stepMinutes = 5;
const minutesPerDay = 24 * 60;
const millisecondsPerMinute = 60 * 1000;

// 記録したときのタイムゾーンの時計の時刻。秒は切り捨てる（時計に見える分）
const computeMinuteOfDay = (instant: Date, timeZone: string): number => {
  const localMilliseconds = instant.getTime() + computeUtcOffsetSeconds(instant, timeZone) * 1000;
  const millisecondsOfDay =
    ((localMilliseconds % millisecondsPerDay) + millisecondsPerDay) % millisecondsPerDay;
  return Math.floor(millisecondsOfDay / millisecondsPerMinute);
};

// 並べた値を受け取る。数が偶数のときは真ん中の2つの平均
const computeMedian = (sorted: readonly number[]): number => {
  const middle = Math.floor(sorted.length / 2);
  const upper = sorted[middle];
  const lower = sorted.length % 2 === 0 ? sorted[middle - 1] : upper;
  if (upper === undefined || lower === undefined) {
    throw new Error("中央値を出す値が無い");
  }
  return (lower + upper) / 2;
};

// 近いほうへ。ちょうど真ん中なら遅いほうへ。24:00 になるときは 23:55
const roundToStep = (minute: number): number =>
  Math.min(Math.floor(minute / stepMinutes + 0.5) * stepMinutes, minutesPerDay - stepMinutes);
