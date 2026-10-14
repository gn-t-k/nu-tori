import { describe, expect, test } from "vitest";
import { isAcceptedDeadline } from "./index";

describe("期限を受け付けるか", () => {
  describe("開始の日からの日数が 27 日のとき", () => {
    test("受け付けないこと", () => {
      expect(isAcceptedDeadline({ startDay: "2026-10-01", deadlineDay: "2026-10-27" })).toBe(false);
    });
  });

  describe("開始の日からの日数が 28 日のとき", () => {
    test("受け付けること", () => {
      expect(isAcceptedDeadline({ startDay: "2026-10-01", deadlineDay: "2026-10-28" })).toBe(true);
    });
  });

  describe("開始の日からの日数が 182 日のとき", () => {
    test("受け付けること", () => {
      expect(isAcceptedDeadline({ startDay: "2026-10-01", deadlineDay: "2027-03-31" })).toBe(true);
    });
  });

  describe("開始の日からの日数が 183 日のとき", () => {
    test("受け付けないこと", () => {
      expect(isAcceptedDeadline({ startDay: "2026-10-01", deadlineDay: "2027-04-01" })).toBe(false);
    });
  });
});
