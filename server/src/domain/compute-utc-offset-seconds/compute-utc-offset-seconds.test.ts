import { describe, expect, test } from "vitest";
import testCases from "../../../../shared/calendar-day-in-time-zone.test-cases.json";
import { computeUtcOffsetSeconds } from "./index";

describe("タイムゾーンのその時刻の時差", () => {
  test.for(testCases)(
    "$name とき、その時刻の UTC との時差を秒で返すこと",
    ({ instant, timeZone, utcOffsetSeconds }) => {
      expect(computeUtcOffsetSeconds(new Date(instant), timeZone)).toBe(utcOffsetSeconds);
    },
  );
});
