import { countDaysBetween } from "../../../domain/count-days-between";

// ある日（YYYY-MM-DD）から期限の日までの日数。両端を含めて数える
export const countDaysInclusive = (fromDay: string, toDay: string): number =>
  countDaysBetween(fromDay, toDay) + 1;
