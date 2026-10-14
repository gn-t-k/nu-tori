import { millisecondsPerDay } from "./milliseconds-per-day";

// YYYY-MM-DD の日付から日付までの日数（前なら負）。同じ日は 0
export const countDaysBetween = (fromDay: string, toDay: string): number =>
  Math.round(
    (Date.parse(`${toDay}T00:00:00Z`) - Date.parse(`${fromDay}T00:00:00Z`)) / millisecondsPerDay,
  );
