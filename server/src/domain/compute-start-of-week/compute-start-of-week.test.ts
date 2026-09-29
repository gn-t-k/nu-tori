import { describe, expect, test } from "vitest";
import testCases from "../../../../shared/start-of-week.test-cases.json";
import { computeStartOfWeek } from "./index";

describe("週の区切り", () => {
  test.for(testCases)(
    "$name の日は、その週の月曜から始まる週に入れること",
    ({ calendarDay, startOfWeek }) => {
      expect(computeStartOfWeek(calendarDay)).toBe(startOfWeek);
    },
  );
});
