import { describe, expect, test } from "vitest";
import testCases from "../../../../shared/calendar-day-in-time-zone.test-cases.json";
import { computeCalendarDayInTimeZone } from "./index";

describe("タイムゾーンから出す日の区切り", () => {
  test.for(testCases)(
    "$name とき、その時刻の時差から出した日に入れること",
    ({ instant, timeZone, calendarDay }) => {
      expect(computeCalendarDayInTimeZone(new Date(instant), timeZone)).toBe(calendarDay);
    },
  );
});
