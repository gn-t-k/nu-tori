import { describe, expect, test } from "vitest";
import testCases from "../../../../shared/calendar-day.test-cases.json";
import { computeCalendarDay } from "./index";

describe("日の区切り", () => {
  test.for(testCases)(
    "$name とき、記録したときのタイムゾーンでの日付の日に入れること",
    ({ instant, timeZone, calendarDay }) => {
      expect(computeCalendarDay(new Date(instant), timeZone)).toBe(calendarDay);
    },
  );
});
