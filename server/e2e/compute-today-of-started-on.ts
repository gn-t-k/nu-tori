import { computeCalendarDayInTimeZone } from "../src/domain/compute-calendar-day-in-time-zone";

// 確かめのサインインはタイムゾーンを送らないので、使い始めた日と無料体験の最後の日は UTC の日付で数えられる
export const computeTodayOfStartedOn = (): string =>
  computeCalendarDayInTimeZone(new Date(), "UTC");
