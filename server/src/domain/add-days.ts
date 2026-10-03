import { millisecondsPerDay } from "./milliseconds-per-day";

// YYYY-MM-DD の日付を、days 日（負なら前へ）ずらした日付
export const addDays = (calendarDay: string, days: number): string =>
  new Date(Date.parse(`${calendarDay}T00:00:00Z`) + days * millisecondsPerDay)
    .toISOString()
    .slice(0, "YYYY-MM-DD".length);
