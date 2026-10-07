import { generateRecordId } from "../../domain/record-id";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { signInTestAccount } from "../../http/testing";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";
import { sourceDeletedWeightRecordWrite } from "../../weight-record/http/testing/source-deleted-weight-record-write";
import { updateWeightRecordWrite } from "../../weight-record/http/testing/update-weight-record-write";
import { beforeEach, describe, expect, test } from "vitest";

describe("いつもの時刻の同期", () => {
  let sessionToken: string;
  let clock: ReturnType<typeof useFakeClock>;
  // 基準の今日（日本時間）から days 日前の、日本時間の hh:mm の時刻
  let tokyoTime: (days: number, time: string) => number;
  // 時計を進めてから送る。偽の時計は止まっているので、要求ごとに受け取った時刻を変え、後の要求を後にする
  let push: (writes: unknown[], clientState?: Record<string, unknown>) => Promise<void>;
  let pullUsualWeighingTime: (afterSequence?: number) => Promise<PullResult["changes"]>;
  let lastSequence: () => Promise<number>;

  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ sessionToken } = await signInTestAccount(generateRecordId()));
    // 使い始めた日より前の記録は直せないので、基準の今日を 60 日先の日本時間の昼にする
    const today = computeCalendarDayInTimeZone(
      new Date(Date.now() + 60 * dayMilliseconds),
      "Asia/Tokyo",
    );
    clock = useFakeClock(Date.parse(`${today}T12:00:00+09:00`));
    tokyoTime = (days, time) => Date.parse(`${today}T${time}:00+09:00`) - days * dayMilliseconds;
    push = async (writes, clientState = {}) => {
      clock.advance(1000);
      const response = await pushSyncWrites(sessionToken, { writes, clientState });
      if (response.status !== 200) {
        throw new Error(`前提: 送る要求が 200 を返す（${response.status}）`);
      }
    };
    pullUsualWeighingTime = async (afterSequence = 0) => {
      const pulled = await (
        await pullSyncChanges(sessionToken, { afterSequence })
      ).json<PullResult>();
      return pulled.changes.filter(({ kind }) => kind.startsWith("usual_weighing_time"));
    };
    lastSequence = async () =>
      (await (await pullSyncChanges(sessionToken)).json<PullResult>()).nextAfterSequence;
  });

  describe("記録のある日が2日のとき", () => {
    beforeEach(async () => {
      await push([weightAt(tokyoTime(2, "07:00"))]);
      await push([weightAt(tokyoTime(1, "07:10"))]);
    });

    test("いつもの時刻が届かないこと", async () => {
      expect(await pullUsualWeighingTime()).toEqual([]);
    });

    describe("3日目の体重記録を作ったとき", () => {
      beforeEach(async () => {
        await push([weightAt(tokyoTime(0, "08:00"))]);
      });

      test("学んだいつもの時刻が届くこと", async () => {
        expect(await pullUsualWeighingTime()).toEqual([
          {
            sequence: expect.any(Number),
            kind: "usual_weighing_time",
            recordId: expect.any(String),
            record: { minuteOfDay: 7 * 60 + 10 },
          },
        ]);
      });
    });
  });

  describe("いつもの時刻を学んだあと", () => {
    let records: ReturnType<typeof weightAt>[];
    let learnedRecordId: string | undefined;
    let afterLearned: number;

    beforeEach(async () => {
      records = [
        weightAt(tokyoTime(2, "07:00")),
        weightAt(tokyoTime(1, "07:10")),
        weightAt(tokyoTime(0, "08:00")),
      ];
      for (const record of records) {
        await push([record]);
      }
      learnedRecordId = (await pullUsualWeighingTime())[0]?.recordId;
      afterLearned = await lastSequence();
    });

    describe("値の変わらない体重記録を作ったとき", () => {
      beforeEach(async () => {
        await push([weightAt(tokyoTime(3, "07:10"))]);
      });

      test("変更の並びに出ないこと", async () => {
        expect(await pullUsualWeighingTime(afterLearned)).toEqual([]);
      });
    });

    describe("値の変わる体重記録を作ったとき", () => {
      beforeEach(async () => {
        await push([weightAt(tokyoTime(3, "08:30"))]);
      });

      test("学び直した値が、同じ記録の変更として届くこと", async () => {
        expect(await pullUsualWeighingTime(afterLearned)).toEqual([
          {
            sequence: expect.any(Number),
            kind: "usual_weighing_time",
            recordId: learnedRecordId,
            record: { minuteOfDay: 7 * 60 + 35 },
          },
        ]);
      });
    });

    describe("範囲の外（28 日前）の体重記録を作ったとき", () => {
      beforeEach(async () => {
        await push([weightAt(tokyoTime(28, "21:00"))]);
      });

      test("変更の並びに出ないこと", async () => {
        expect(await pullUsualWeighingTime(afterLearned)).toEqual([]);
      });
    });

    describe("体重記録の時刻を直したとき", () => {
      beforeEach(async () => {
        const middle = records[1];
        if (middle === undefined) {
          throw new Error("前提: 2つ目の体重記録がある");
        }
        await push([
          updateWeightRecordWrite(String(middle.weightRecord["id"]), {
            weightRecord: { measuredAt: tokyoTime(1, "07:50") },
          }),
        ]);
      });

      test("直したあとの体重記録で学び直した値が届くこと", async () => {
        expect(await pullUsualWeighingTime(afterLearned)).toEqual([
          expect.objectContaining({ record: { minuteOfDay: 7 * 60 + 50 } }),
        ]);
      });
    });

    describe("体重記録をすべて消したとき", () => {
      beforeEach(async () => {
        await push(
          records.map((record) =>
            sourceDeletedWeightRecordWrite(String(record.weightRecord["id"])),
          ),
        );
      });

      test("最後の値が残ること", async () => {
        expect(await pullUsualWeighingTime()).toEqual([
          expect.objectContaining({
            recordId: learnedRecordId,
            record: { minuteOfDay: 7 * 60 + 10 },
          }),
        ]);
      });
    });
  });

  describe("取り込んだ体重記録で、いつもの時刻が変わったとき", () => {
    let imported: ReturnType<typeof weightAt>;
    let afterImported: number;

    beforeEach(async () => {
      imported = weightAt(tokyoTime(3, "08:30"), {
        imported: {
          sourceAppName: "体重計",
          sourceBundleId: "com.example.scale",
          healthkitSampleUuid: generateRecordId(),
        },
      });
      await push([
        weightAt(tokyoTime(2, "07:00")),
        weightAt(tokyoTime(1, "07:10")),
        weightAt(tokyoTime(0, "08:00")),
      ]);
      await push([imported]);
      afterImported = await lastSequence();
    });

    test("取り込んだ体重記録の時刻から学ぶこと", async () => {
      expect(await pullUsualWeighingTime()).toEqual([
        expect.objectContaining({ record: { minuteOfDay: 7 * 60 + 35 } }),
      ]);
    });

    describe("元のサンプルが消えた知らせを送ったとき", () => {
      beforeEach(async () => {
        await push([sourceDeletedWeightRecordWrite(String(imported.weightRecord["id"]))]);
      });

      test("消えたあとの体重記録で学び直した値が届くこと", async () => {
        expect(await pullUsualWeighingTime(afterImported)).toEqual([
          expect.objectContaining({ record: { minuteOfDay: 7 * 60 + 10 } }),
        ]);
      });
    });
  });

  describe("1つの要求で、体重記録を作る書き込みを複数送ったとき", () => {
    beforeEach(async () => {
      await push([
        weightAt(tokyoTime(3, "08:30")),
        weightAt(tokyoTime(2, "07:00")),
        weightAt(tokyoTime(1, "07:10")),
        weightAt(tokyoTime(0, "08:00")),
      ]);
    });

    test("最後の書き込みのあとで学び直した値が届くこと", async () => {
      expect(await pullUsualWeighingTime()).toEqual([
        expect.objectContaining({ record: { minuteOfDay: 7 * 60 + 35 } }),
      ]);
    });
  });

  // 基準の今日の昼（日本時間）は、パゴパゴ（UTC−11）では前の日の夕方
  describe("基準の今日の日本時間の朝の記録を含めて3日あるとき", () => {
    let writes: ReturnType<typeof weightAt>[];

    beforeEach(() => {
      writes = [
        weightAt(tokyoTime(2, "07:00")),
        weightAt(tokyoTime(1, "07:10")),
        weightAt(tokyoTime(0, "08:00")),
      ];
    });

    describe("ユーザーの最新のタイムゾーンが日本時間のとき", () => {
      beforeEach(async () => {
        await push(writes, { timeZone: "Asia/Tokyo" });
      });

      test("日本時間の今日までを範囲にして、いつもの時刻が届くこと", async () => {
        expect(await pullUsualWeighingTime()).toEqual([
          expect.objectContaining({ record: { minuteOfDay: 7 * 60 + 10 } }),
        ]);
      });
    });

    describe("ユーザーの最新のタイムゾーンがパゴパゴのとき", () => {
      beforeEach(async () => {
        await push(writes, { timeZone: "Pacific/Pago_Pago" });
      });

      test("パゴパゴの今日より後の記録を範囲から外し、いつもの時刻が届かないこと", async () => {
        expect(await pullUsualWeighingTime()).toEqual([]);
      });
    });
  });
});

const dayMilliseconds = 24 * 60 * 60 * 1000;

const weightAt = (measuredAt: number, weightRecord: Record<string, unknown> = {}) =>
  createWeightRecordWrite({ weightRecord: { measuredAt, ...weightRecord } });
