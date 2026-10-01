import { describe, expect, test } from "vitest";
import testCases from "../../../../shared/calendar-day.test-cases.json";
import { computeCalendarDay } from "./index";

describe("日の区切り", () => {
  test.for(testCases)(
    "$name とき、時刻に時差を足した UTC の日付の日に入れること",
    ({ instant, utcOffsetSeconds, calendarDay }) => {
      expect(computeCalendarDay(new Date(instant), utcOffsetSeconds)).toBe(calendarDay);
    },
  );
});
