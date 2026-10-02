import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { signInTestAccount } from "../../http/testing";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";
import { sourceDeletedWeightRecordWrite } from "../../weight-record/http/testing/source-deleted-weight-record-write";
import { updateWeightRecordWrite } from "../../weight-record/http/testing/update-weight-record-write";
import { beforeEach, describe, expect, test } from "vitest";

describe("体重の傾向の同期", () => {
  let sessionToken: string;
  let pullWeightTrend: () => Promise<PullResult["changes"]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ sessionToken } = await signInTestAccount(crypto.randomUUID()));
    pullWeightTrend = async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      return pulled.changes.filter(({ kind }) => kind.startsWith("weight_trend"));
    };
  });

  describe("記録の無い日を挟んで、体重記録を作る書き込みを送ったとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, {
        writes: [
          createWeightRecordWrite({
            weightRecord: {
              weightKg: 72.0,
              measuredAt: Date.parse("2026-09-01T07:00:00+09:00"),
              timeZone: "Asia/Tokyo",
            },
          }),
        ],
      });
      await pushSyncWrites(sessionToken, {
        writes: [
          createWeightRecordWrite({
            weightRecord: {
              weightKg: 71.6,
              measuredAt: Date.parse("2026-09-03T07:00:00+09:00"),
              timeZone: "Asia/Tokyo",
            },
          }),
        ],
      });
    });

    test("取りに行くと、始まりの日から最後の記録の日までの傾向の並び全体が1つ返ること", async () => {
      expect(await pullWeightTrend()).toEqual([
        {
          sequence: expect.any(Number),
          kind: "weight_trend",
          recordId: "weight_trend",
          record: {
            days: [
              { calendarDay: "2026-09-01", trendKg: 72.0 },
              { calendarDay: "2026-09-02", trendKg: expect.closeTo(71.98, 10) },
              { calendarDay: "2026-09-03", trendKg: expect.closeTo(71.942, 10) },
            ],
          },
        },
      ]);
    });
  });

  describe("使い始めた日から3日続けて体重記録があるとき", () => {
    let middleRecordId: string;
    let middleMeasuredAt: number;
    beforeEach(async () => {
      // 使い始めた日より前の記録は直せないので、今から1日ずつ記録する
      const dayMs = 24 * 60 * 60 * 1000;
      const firstMeasuredAt = Date.now();
      middleMeasuredAt = firstMeasuredAt + dayMs;
      const middle = createWeightRecordWrite({
        weightRecord: { weightKg: 72.0, measuredAt: middleMeasuredAt, timeZone: "Asia/Tokyo" },
      });
      middleRecordId = String(middle.weightRecord["id"]);
      await pushSyncWrites(sessionToken, {
        writes: [
          createWeightRecordWrite({
            weightRecord: { weightKg: 72.0, measuredAt: firstMeasuredAt, timeZone: "Asia/Tokyo" },
          }),
          middle,
          createWeightRecordWrite({
            weightRecord: {
              weightKg: 72.0,
              measuredAt: firstMeasuredAt + 2 * dayMs,
              timeZone: "Asia/Tokyo",
            },
          }),
        ],
      });
    });

    describe("真ん中の日の記録を直したとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, {
          writes: [
            updateWeightRecordWrite(middleRecordId, {
              weightRecord: {
                weightKg: 73.0,
                measuredAt: middleMeasuredAt,
                timeZone: "Asia/Tokyo",
              },
            }),
          ],
        });
      });

      test("前の日の傾向はそのままで、直した日からあとの傾向が変わること", async () => {
        expect((await pullWeightTrend())[0]?.record).toEqual({
          days: [
            { calendarDay: expect.any(String), trendKg: 72.0 },
            { calendarDay: expect.any(String), trendKg: expect.closeTo(72.1, 10) },
            { calendarDay: expect.any(String), trendKg: expect.closeTo(72.09, 10) },
          ],
        });
      });
    });
  });

  describe("体重記録が1つだけあるとき", () => {
    let recordId: string;
    beforeEach(async () => {
      const create = createWeightRecordWrite();
      recordId = String(create.weightRecord["id"]);
      await pushSyncWrites(sessionToken, { writes: [create] });
    });

    describe("元のサンプルが消えた知らせを送り、体重記録が無くなったとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, { writes: [sourceDeletedWeightRecordWrite(recordId)] });
      });

      test("取りに行くと、傾向が無いことが返ること", async () => {
        expect(await pullWeightTrend()).toEqual([
          {
            sequence: expect.any(Number),
            kind: "weight_trend_absence",
            recordId: "weight_trend",
            record: {},
          },
        ]);
      });
    });
  });

  describe("体重記録が無いまま、届いていない記録の元のサンプルが消えた知らせを送ったとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, {
        writes: [sourceDeletedWeightRecordWrite(crypto.randomUUID())],
      });
    });

    test("取りに行くと、傾向が無いことが返ること", async () => {
      expect((await pullWeightTrend()).map(({ kind }) => kind)).toEqual(["weight_trend_absence"]);
    });
  });

  describe("使い始める前の日の体重記録を取り込んだとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, {
        writes: [
          createWeightRecordWrite({
            weightRecord: {
              weightKg: 73.0,
              measuredAt: Date.parse("2020-01-01T07:00:00+09:00"),
              timeZone: "Asia/Tokyo",
              imported: {
                sourceAppName: "Withings",
                sourceBundleId: "com.withings.wiScaleNG",
                healthkitSampleUuid: crypto.randomUUID(),
              },
            },
          }),
        ],
      });
    });

    test("その日から傾向が始まること", async () => {
      expect((await pullWeightTrend())[0]?.record).toEqual({
        days: [{ calendarDay: "2020-01-01", trendKg: 73.0 }],
      });
    });
  });
});
