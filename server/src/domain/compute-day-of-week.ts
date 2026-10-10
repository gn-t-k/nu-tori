import type { DayOfWeek } from "./day-of-week";

// YYYY-MM-DD の日付の曜日
export const computeDayOfWeek = (calendarDay: string): DayOfWeek => {
  const daysOfWeek = [
    "sunday",
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
  ] as const;
  const dayOfWeek = daysOfWeek[new Date(`${calendarDay}T00:00:00Z`).getUTCDay()];
  if (dayOfWeek === undefined) {
    throw new Error(`曜日を出せなかった: ${calendarDay}`);
  }
  return dayOfWeek;
};
