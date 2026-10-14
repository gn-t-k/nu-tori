import { describe, expect, test } from "vitest";
import testCases from "../../../../../shared/daily-guide-for-day.test-cases.json";
import { findDailyGuideForDay } from "./index";

describe("その日の1日の目安", () => {
  test.for(testCases)(
    "$name とき、その日を含む目標と、その目標の当てる始まりの日がその日以前で最も遅い1日の目安を返すこと",
    ({ calendarDay, goals, dailyGuides, goalId, dailyGuideId }) => {
      const found = findDailyGuideForDay(
        calendarDay,
        goals.map((goal) => ({
          id: goal.id,
          startedOn: goal.startedOn,
          decidedAt: new Date(goal.decidedAt),
          // 閉じていない目標は、JSON に終わった日のキーが無い
          endedOn: "endedOn" in goal ? goal.endedOn : undefined,
        })),
        dailyGuides,
      );

      expect({
        goalId: found?.goal.id ?? null,
        dailyGuideId: found?.dailyGuide?.id ?? null,
      }).toEqual({ goalId, dailyGuideId });
    },
  );
});
