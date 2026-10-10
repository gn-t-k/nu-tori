import type { DayOfWeek } from "./reply-context";

// YYYY-MM-DD の日付の曜日
export const computeDayOfWeek = (calendarDay: string): DayOfWeek => {
  const daysOfWeek = ["日", "月", "火", "水", "木", "金", "土"] as const;
  const dayOfWeek = daysOfWeek[new Date(`${calendarDay}T00:00:00Z`).getUTCDay()];
  if (dayOfWeek === undefined) {
    throw new Error(`曜日を出せなかった: ${calendarDay}`);
  }
  return dayOfWeek;
};
