import { beforeEach, describe, expect, test } from "vitest";
import testCases from "../../../../../shared/accepted-deadline-days.test-cases.json";
import { countAcceptedDaysToDeadline, moveDeadlineIntoAcceptedRange } from "./index";

describe("受け付ける期限", () => {
  describe("開始の日から期限の日までの日数", () => {
    test.for(testCases.filter(({ accepted }) => accepted))(
      "$name を受け付けること",
      ({ startedOn, deadlineOn }) => {
        expect(countAcceptedDaysToDeadline({ startedOn, deadlineOn })).toBeSuccess();
      },
    );

    test.for(testCases.filter(({ accepted }) => !accepted))(
      "$name を受け付けないこと",
      ({ startedOn, deadlineOn }) => {
        expect(countAcceptedDaysToDeadline({ startedOn, deadlineOn })).toBeFailure();
      },
    );

    describe("受け付ける期限のとき", () => {
      let input: Parameters<typeof countAcceptedDaysToDeadline>[0];

      beforeEach(() => {
        input = { startedOn: "2026-12-30", deadlineOn: "2027-02-10" };
      });

      test("両端を含めて数えた日数を返すこと", () => {
        expect(countAcceptedDaysToDeadline(input)).toBeSuccess((days) => {
          expect(days).toBe(43);
        });
      });
    });

    describe("受け付けない期限のとき", () => {
      let input: Parameters<typeof countAcceptedDaysToDeadline>[0];

      beforeEach(() => {
        input = { startedOn: "2026-10-01", deadlineOn: "2026-10-27" };
      });

      test("期限が受け付ける幅の外だという理由で失敗すること", () => {
        expect(countAcceptedDaysToDeadline(input)).toBeFailure((error) => {
          expect(error.reason).toBe("deadline_out_of_range");
        });
      });
    });
  });

  describe("期限を受け付ける幅に寄せる", () => {
    describe("期限が受け付けるいちばん短い日より前のとき", () => {
      let input: Parameters<typeof moveDeadlineIntoAcceptedRange>[0];

      beforeEach(() => {
        input = { startedOn: "2026-10-01", deadlineOn: "2026-10-20" };
      });

      test("開始の日から 28 日めに寄せること", () => {
        expect(moveDeadlineIntoAcceptedRange(input)).toBe("2026-10-28");
      });
    });

    describe("期限が受け付けるいちばん長い日より後のとき", () => {
      let input: Parameters<typeof moveDeadlineIntoAcceptedRange>[0];

      beforeEach(() => {
        input = { startedOn: "2026-10-01", deadlineOn: "2027-05-01" };
      });

      test("開始の日から 182 日めに寄せること", () => {
        expect(moveDeadlineIntoAcceptedRange(input)).toBe("2027-03-31");
      });
    });

    describe("期限が受け付ける幅の中のとき", () => {
      let input: Parameters<typeof moveDeadlineIntoAcceptedRange>[0];

      beforeEach(() => {
        input = { startedOn: "2026-10-01", deadlineOn: "2026-12-15" };
      });

      test("期限をそのまま返すこと", () => {
        expect(moveDeadlineIntoAcceptedRange(input)).toBe("2026-12-15");
      });
    });
  });
});
