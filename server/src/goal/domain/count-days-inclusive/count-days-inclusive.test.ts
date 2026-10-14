import { describe, expect, test } from "vitest";
import { countDaysInclusive } from "./index";

describe("両端を含めた日数", () => {
  describe("同じ日のとき", () => {
    test("1日と数えること", () => {
      expect(countDaysInclusive("2026-10-14", "2026-10-14")).toBe(1);
    });
  });

  describe("月と年をまたぐとき", () => {
    test("始まりの日と終わりの日の両方を数えること", () => {
      expect(countDaysInclusive("2026-12-30", "2027-01-02")).toBe(4);
    });
  });
});
