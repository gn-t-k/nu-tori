import { describe, expect, test } from "vitest";
import { decideGoalStartDay } from "./index";

describe("開始の日", () => {
  describe("初めて目標を立てるとき", () => {
    test("端末の今日にすること", () => {
      expect(decideGoalStartDay({ today: "2026-10-14", currentGoalStartDay: undefined })).toBe(
        "2026-10-14",
      );
    });
  });

  describe("立て直すときで、今日が今の目標の開始の日より後のとき", () => {
    test("端末の今日にすること", () => {
      expect(decideGoalStartDay({ today: "2026-10-14", currentGoalStartDay: "2026-09-30" })).toBe(
        "2026-10-14",
      );
    });
  });

  describe("立て直すときで、今日が今の目標の開始の日より前のとき", () => {
    test("今の目標の開始の日にすること", () => {
      expect(decideGoalStartDay({ today: "2026-10-13", currentGoalStartDay: "2026-10-14" })).toBe(
        "2026-10-14",
      );
    });
  });
});
