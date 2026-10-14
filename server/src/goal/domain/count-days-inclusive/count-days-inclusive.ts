import { millisecondsPerDay } from "../../../domain/milliseconds-per-day";

// ある日（YYYY-MM-DD）から期限の日までの日数。両端を含めて数える
export const countDaysInclusive = (fromDay: string, toDay: string): number =>
  Math.round(
    (Date.parse(`${toDay}T00:00:00Z`) - Date.parse(`${fromDay}T00:00:00Z`)) / millisecondsPerDay,
  ) + 1;
