import { beforeEach, describe, expect, test } from "vitest";
import { countReviewedWeekMealDays } from "./index";
import { daysFrom } from "../../testing/days-from";

// 見直す月曜は 2026-10-19。見直す入力の週は 2026-10-12（月）〜 2026-10-18（日）
const reviewedMonday = "2026-10-19";

const intakesOn = (calendarDays: string[]) =>
  calendarDays.map((calendarDay) => ({ calendarDay, kcal: 2000 }));

describe("前に見直せた週の食事を記録した日数", () => {
  describe("その週に食事を記録した日が5日あるとき", () => {
    let counted: number;
    beforeEach(() => {
      counted = countReviewedWeekMealDays(reviewedMonday, intakesOn(daysFrom("2026-10-12", 5)));
    });

    test("5日と数えること", () => {
      expect(counted).toBe(5);
    });
  });

  describe("見直したあとに食事を消して、その週に食事を記録した日が2日になったとき", () => {
    let counted: number;
    beforeEach(() => {
      counted = countReviewedWeekMealDays(reviewedMonday, intakesOn(daysFrom("2026-10-12", 2)));
    });

    test("見送らない最小の4日と数えること", () => {
      expect(counted).toBe(4);
    });
  });
});
