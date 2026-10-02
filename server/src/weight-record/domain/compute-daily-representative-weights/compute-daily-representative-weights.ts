import { computeCalendarDayInTimeZone } from "../../../domain/compute-calendar-day-in-time-zone";

// 日は記録したときのタイムゾーンの日付。同じ時刻の記録は ID の順で先のものにし、入力の順に左右されないようにする
export const computeDailyRepresentativeWeights = <
  TWeightRecord extends { id: string; measuredAt: Date; timeZone: string },
>(
  weightRecords: readonly TWeightRecord[],
): { calendarDay: string; weightRecord: TWeightRecord }[] => {
  const representatives = new Map<string, TWeightRecord>();
  for (const weightRecord of weightRecords) {
    const calendarDay = computeCalendarDayInTimeZone(
      weightRecord.measuredAt,
      weightRecord.timeZone,
    );
    const current = representatives.get(calendarDay);
    if (current === undefined || isEarlier(weightRecord, current)) {
      representatives.set(calendarDay, weightRecord);
    }
  }
  return [...representatives]
    .map(([calendarDay, weightRecord]) => ({ calendarDay, weightRecord }))
    .toSorted((a, b) => a.calendarDay.localeCompare(b.calendarDay));
};

const isEarlier = (
  a: { id: string; measuredAt: Date },
  b: { id: string; measuredAt: Date },
): boolean => {
  const difference = a.measuredAt.getTime() - b.measuredAt.getTime();
  return difference === 0 ? a.id < b.id : difference < 0;
};
