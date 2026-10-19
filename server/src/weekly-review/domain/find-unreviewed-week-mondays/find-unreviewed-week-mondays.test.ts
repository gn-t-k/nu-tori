import { describe, expect, test } from "vitest";
import { findUnreviewedWeekMondays } from "./index";

// 2026-10-12 と 2026-10-19 は月曜
describe("まだ見直していない週", () => {
  describe("目標がまだ無いとき", () => {
    test("見直す週が無いこと", () => {
      expect(
        findUnreviewedWeekMondays({
          today: "2026-10-19",
          firstGoalStartedOn: undefined,
          latestReviewEffectiveOn: undefined,
          latestEstimateEffectiveOn: undefined,
        }),
      ).toEqual([]);
    });
  });

  describe("水曜に初めて目標を立て、まだ1週も見直していないとき", () => {
    test("立てた日のあとの最初の月曜から、今週の月曜までを古い順に見直すこと", () => {
      expect(
        findUnreviewedWeekMondays({
          today: "2026-10-19",
          firstGoalStartedOn: "2026-10-07",
          latestReviewEffectiveOn: undefined,
          latestEstimateEffectiveOn: "2026-10-07",
        }),
      ).toEqual(["2026-10-12", "2026-10-19"]);
    });
  });

  describe("月曜に初めて目標を立てたとき", () => {
    test("その週のうちは見直す週が無いこと", () => {
      expect(
        findUnreviewedWeekMondays({
          today: "2026-10-18",
          firstGoalStartedOn: "2026-10-12",
          latestReviewEffectiveOn: undefined,
          latestEstimateEffectiveOn: "2026-10-12",
        }),
      ).toEqual([]);
    });

    test("立てた月曜を見直さず、次の月曜から見直すこと", () => {
      expect(
        findUnreviewedWeekMondays({
          today: "2026-10-19",
          firstGoalStartedOn: "2026-10-12",
          latestReviewEffectiveOn: undefined,
          latestEstimateEffectiveOn: "2026-10-12",
        }),
      ).toEqual(["2026-10-19"]);
    });
  });

  describe("最も遅い見直しの月曜から何週もあとの水曜のとき", () => {
    test("その次の月曜から、今週の月曜までを古い順に見直すこと", () => {
      expect(
        findUnreviewedWeekMondays({
          today: "2026-11-04",
          firstGoalStartedOn: "2026-10-07",
          latestReviewEffectiveOn: "2026-10-12",
          latestEstimateEffectiveOn: "2026-10-07",
        }),
      ).toEqual(["2026-10-19", "2026-10-26", "2026-11-02"]);
    });
  });

  describe("今週の月曜をもう見直したとき", () => {
    test("見直す週が無いこと", () => {
      expect(
        findUnreviewedWeekMondays({
          today: "2026-10-21",
          firstGoalStartedOn: "2026-10-07",
          latestReviewEffectiveOn: "2026-10-19",
          latestEstimateEffectiveOn: "2026-10-07",
        }),
      ).toEqual([]);
    });
  });
});
