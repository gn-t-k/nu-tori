import { computeCalendarDay } from "../compute-calendar-day";
import { computeUtcOffsetSeconds } from "../compute-utc-offset-seconds";

// timeZone は isTimeZoneName で確かめた IANA 名を渡す
export const computeCalendarDayInTimeZone = (instant: Date, timeZone: string): string =>
  computeCalendarDay(instant, computeUtcOffsetSeconds(instant, timeZone));
