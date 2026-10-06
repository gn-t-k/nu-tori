import { beforeEach, describe, expect, test } from "vitest";
import { learnUsualWeighingTime } from "./index";

describe("いつもの時刻の学習", () => {
  describe("出し方", () => {
    describe("記録のある日が3日のとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-28T07:21:00"),
            inTokyo("b", "2026-09-29T07:02:00"),
            inTokyo("c", "2026-09-30T07:10:00"),
          ],
          now: new Date("2026-09-30T12:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("時刻の中央値を、その日の何分目で出すこと", () => {
        expect(learned).toBe(7 * 60 + 10);
      });
    });

    describe("記録のある日が偶数のとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-27T07:02:00"),
            inTokyo("b", "2026-09-28T07:10:00"),
            inTokyo("c", "2026-09-29T07:21:00"),
            inTokyo("d", "2026-09-30T21:40:00"),
          ],
          now: new Date("2026-09-30T22:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("真ん中の2つの平均を5分単位に丸めること", () => {
        expect(learned).toBe(7 * 60 + 15);
      });
    });

    describe("同じ日に記録が2つあるとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-28T07:00:00"),
            inTokyo("b", "2026-09-29T07:00:00"),
            inTokyo("c", "2026-09-30T06:00:00"),
            inTokyo("d", "2026-09-30T22:00:00"),
          ],
          now: new Date("2026-09-30T23:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("その日の最初の記録の時刻だけを使うこと", () => {
        expect(learned).toBe(7 * 60);
      });
    });
  });

  describe("時刻の無い記録", () => {
    describe("記録したときの時計で 0:00:00 ちょうどの記録だけが3日あるとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-28T00:00:00"),
            inTokyo("b", "2026-09-29T00:00:00"),
            inTokyo("c", "2026-09-30T00:00:00"),
          ],
          now: new Date("2026-09-30T12:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("材料から外し、いつもの時刻を出さないこと", () => {
        expect(learned).toBeUndefined();
      });
    });

    describe("0:00:00 ちょうどの記録と同じ日に、ほかの記録があるとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-28T00:00:00"),
            inTokyo("b", "2026-09-28T07:00:00"),
            inTokyo("c", "2026-09-29T00:00:00"),
            inTokyo("d", "2026-09-29T07:10:00"),
            inTokyo("e", "2026-09-30T00:00:00"),
            inTokyo("f", "2026-09-30T07:20:00"),
          ],
          now: new Date("2026-09-30T12:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("ほかの記録をその日の最初の記録にすること", () => {
        expect(learned).toBe(7 * 60 + 10);
      });
    });

    describe("0:00 台でも 0:00:00 ちょうどではない記録のとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-28T00:00:01"),
            inTokyo("b", "2026-09-29T00:01:00"),
            inTokyo("c", "2026-09-30T00:02:00"),
          ],
          now: new Date("2026-09-30T12:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("材料に入れること", () => {
        expect(learned).toBe(0);
      });
    });

    describe("ほかのタイムゾーンの 0:00:00 ちょうどの記録のとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-28T07:00:00"),
            inTokyo("b", "2026-09-29T07:00:00"),
            {
              id: "c",
              measuredAt: new Date("2026-09-30T00:00:00-07:00"),
              timeZone: "America/Los_Angeles",
            },
          ],
          now: new Date("2026-09-30T12:00:00-07:00"),
          timeZone: "America/Los_Angeles",
        });
      });

      test("記録したときのタイムゾーンの時計で見分けて外すこと", () => {
        expect(learned).toBeUndefined();
      });
    });
  });

  describe("5分単位の丸め", () => {
    describe("中央値が5分の区切りの真ん中より前のとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-28T07:00:00"),
            inTokyo("b", "2026-09-29T07:02:59"),
            inTokyo("c", "2026-09-30T07:10:00"),
          ],
          now: new Date("2026-09-30T12:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("秒を切り捨てた分から、早いほうへ丸めること", () => {
        expect(learned).toBe(7 * 60);
      });
    });

    describe("中央値が5分の区切りの真ん中より後のとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-28T07:00:00"),
            inTokyo("b", "2026-09-29T07:03:00"),
            inTokyo("c", "2026-09-30T07:10:00"),
          ],
          now: new Date("2026-09-30T12:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("遅いほうへ丸めること", () => {
        expect(learned).toBe(7 * 60 + 5);
      });
    });

    describe("中央値が5分の区切りのちょうど真ん中のとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-27T07:00:00"),
            inTokyo("b", "2026-09-28T07:02:00"),
            inTokyo("c", "2026-09-29T07:03:00"),
            inTokyo("d", "2026-09-30T07:10:00"),
          ],
          now: new Date("2026-09-30T12:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("遅いほうへ丸めること", () => {
        expect(learned).toBe(7 * 60 + 5);
      });
    });

    describe("丸めると 24:00 になるとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-28T23:58:00"),
            inTokyo("b", "2026-09-29T23:58:00"),
            inTokyo("c", "2026-09-30T23:58:00"),
          ],
          now: new Date("2026-09-30T23:59:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("23:55 にすること", () => {
        expect(learned).toBe(23 * 60 + 55);
      });
    });
  });

  describe("3日の条件", () => {
    describe("記録のある日が2日のとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-29T07:00:00"),
            inTokyo("b", "2026-09-30T07:00:00"),
            inTokyo("c", "2026-09-30T08:00:00"),
          ],
          now: new Date("2026-09-30T12:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("いつもの時刻を出さないこと", () => {
        expect(learned).toBeUndefined();
      });
    });
  });

  describe("28日の範囲", () => {
    describe("基準の今日の 27 日前の記録があるとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-03T06:00:00"),
            inTokyo("b", "2026-09-29T07:00:00"),
            inTokyo("c", "2026-09-30T08:00:00"),
          ],
          now: new Date("2026-09-30T12:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("範囲に入れること", () => {
        expect(learned).toBe(7 * 60);
      });
    });

    describe("基準の今日の 28 日前の記録があるとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-02T06:00:00"),
            inTokyo("b", "2026-09-29T07:00:00"),
            inTokyo("c", "2026-09-30T08:00:00"),
          ],
          now: new Date("2026-09-30T12:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("範囲から外すこと", () => {
        expect(learned).toBeUndefined();
      });
    });
  });

  describe("日付の境目とタイムゾーン", () => {
    describe("日付が変わる直前と直後に記録があるとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-28T07:00:00"),
            inTokyo("b", "2026-09-29T23:50:00"),
            inTokyo("c", "2026-09-30T00:10:00"),
          ],
          now: new Date("2026-09-30T12:00:00+09:00"),
          timeZone: "Asia/Tokyo",
        });
      });

      test("別の日の記録として数えること", () => {
        expect(learned).toBe(7 * 60);
      });
    });

    describe("ほかのタイムゾーンで記録したとき", () => {
      let learned: number | undefined;

      beforeEach(() => {
        learned = learnUsualWeighingTime({
          weightRecords: [
            inTokyo("a", "2026-09-26T07:00:00"),
            inTokyo("b", "2026-09-27T07:30:00"),
            {
              id: "c",
              measuredAt: new Date("2026-09-28T06:00:00-07:00"),
              timeZone: "America/Los_Angeles",
            },
          ],
          now: new Date("2026-09-29T12:00:00-07:00"),
          timeZone: "America/Los_Angeles",
        });
      });

      test("記録したときのタイムゾーンの時計の時刻を使うこと", () => {
        expect(learned).toBe(7 * 60);
      });
    });

    describe("基準の今日がタイムゾーンで変わる時刻のとき", () => {
      let learnedInUtc: number | undefined;
      let learnedInTokyo: number | undefined;

      beforeEach(() => {
        const weightRecords = [
          inTokyo("a", "2026-09-03T06:00:00"),
          inTokyo("b", "2026-09-29T07:00:00"),
          inTokyo("c", "2026-09-30T08:00:00"),
        ];
        const now = new Date("2026-09-30T20:00:00Z");
        learnedInUtc = learnUsualWeighingTime({ weightRecords, now, timeZone: "UTC" });
        learnedInTokyo = learnUsualWeighingTime({ weightRecords, now, timeZone: "Asia/Tokyo" });
      });

      test("渡したタイムゾーンの今日から 27 日前までを範囲にすること", () => {
        expect(learnedInUtc).toBe(7 * 60);
      });

      test("渡したタイムゾーンで今日が進めば、その分だけ範囲も進むこと", () => {
        expect(learnedInTokyo).toBeUndefined();
      });
    });
  });
});

const inTokyo = (id: string, localDateTime: string) => ({
  id,
  measuredAt: new Date(`${localDateTime}+09:00`),
  timeZone: "Asia/Tokyo",
});
