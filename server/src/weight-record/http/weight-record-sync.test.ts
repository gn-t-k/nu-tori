import { generateRecordId } from "../../domain/record-id";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { signInTestAccount } from "../../http/testing";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import type { PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { createWeightRecordWrite } from "./testing/create-weight-record-write";
import { pullWeightRecordChanges } from "./testing/pull-weight-record-changes";
import { sourceDeletedWeightRecordWrite } from "./testing/source-deleted-weight-record-write";
import { updateWeightRecordWrite } from "./testing/update-weight-record-write";
import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";

describe("体重記録の同期", () => {
  let accountId: string;
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
  });

  describe("体重記録を作る書き込みを送ったとき", () => {
    let write: ReturnType<typeof createWeightRecordWrite>;
    let response: Response;
    beforeEach(async () => {
      write = createWeightRecordWrite({
        weightRecord: { weightKg: 72.4, measuredAt: 1_767_225_600_000, timeZone: "Asia/Tokyo" },
      });
      response = await pushSyncWrites(sessionToken, { writes: [write] });
    });

    test("当てたと書き込みごとの結果を返すこと", async () => {
      expect({ status: response.status, body: await response.json() }).toEqual({
        status: 200,
        body: { results: [{ writeId: write.id, result: "applied" }] },
      });
    });

    test("取りに行くと、端末が送った値のまま体重記録が返ること", async () => {
      const pulled = await pullWeightRecordChanges(sessionToken);
      expect(pulled.changes).toEqual([
        {
          sequence: expect.any(Number),
          kind: "weight_record",
          recordId: write.weightRecord["id"],
          record: {
            id: write.weightRecord["id"],
            weightKg: 72.4,
            measuredAt: 1_767_225_600_000,
            timeZone: "Asia/Tokyo",
            version: 1,
          },
        },
      ]);
    });
  });

  describe("ヘルスケアから取り込んだ体重記録を作る書き込みを送ったとき", () => {
    let write: ReturnType<typeof createWeightRecordWrite>;
    beforeEach(async () => {
      write = createWeightRecordWrite({
        weightRecord: {
          imported: {
            sourceAppName: "Withings",
            sourceBundleId: "com.withings.wiScaleNG",
            healthkitSampleUuid: generateRecordId(),
            bodyFat: { percentage: 18.5, healthkitSampleUuid: generateRecordId() },
          },
        },
      });
      await pushSyncWrites(sessionToken, { writes: [write] });
    });

    test("出どころと体脂肪率も返ること", async () => {
      const pulled = await pullWeightRecordChanges(sessionToken);
      expect(pulled.changes[0]?.record["imported"]).toEqual(write.weightRecord["imported"]);
    });

    describe("別の ID で同じサンプルの UUID の作る書き込みを送ったとき", () => {
      let sameSample: ReturnType<typeof createWeightRecordWrite>;
      beforeEach(() => {
        sameSample = createWeightRecordWrite({
          weightRecord: { imported: write.weightRecord["imported"] },
        });
      });

      test("捨てること", async () => {
        const response = await pushSyncWrites(sessionToken, { writes: [sameSample] });
        expect((await response.json<PushResults>()).results[0]?.result).toBe("ignored_duplicate");
      });
    });
  });

  describe("同じ ID の体重記録がすでにあるとき", () => {
    let existing: ReturnType<typeof createWeightRecordWrite>;
    beforeEach(async () => {
      existing = createWeightRecordWrite({ weightRecord: { weightKg: 72.4 } });
      await pushSyncWrites(sessionToken, { writes: [existing] });
    });

    describe("別の書き込みの ID で作る書き込みを送ったとき", () => {
      let again: ReturnType<typeof createWeightRecordWrite>;
      let response: Response;
      beforeEach(async () => {
        again = createWeightRecordWrite({
          weightRecord: { id: existing.weightRecord["id"], weightKg: 80 },
        });
        response = await pushSyncWrites(sessionToken, { writes: [again] });
      });

      test("捨てること", async () => {
        expect((await response.json<PushResults>()).results[0]?.result).toBe("ignored_duplicate");
      });

      test("値を変えないこと", async () => {
        const pulled = await pullWeightRecordChanges(sessionToken);
        expect(pulled.changes[0]?.record["weightKg"]).toBe(72.4);
      });
    });
  });

  describe("体重記録がすでにあるとき", () => {
    let recordId: string;
    beforeEach(async () => {
      const create = createWeightRecordWrite({ weightRecord: { weightKg: 72.4 } });
      recordId = String(create.weightRecord["id"]);
      await pushSyncWrites(sessionToken, { writes: [create] });
    });

    describe("直す書き込みを送ったとき", () => {
      beforeEach(async () => {
        const update = updateWeightRecordWrite(recordId, {
          weightRecord: {
            weightKg: 71.9,
            measuredAt: 1_767_229_200_000,
            timeZone: "America/Los_Angeles",
            version: 2,
          },
        });
        await pushSyncWrites(sessionToken, { writes: [update] });
      });

      test("値と時刻とタイムゾーンを置き換え、版を上げて返すこと", async () => {
        const pulled = await pullWeightRecordChanges(sessionToken);
        expect(pulled.changes).toEqual([
          expect.objectContaining({
            record: {
              id: recordId,
              weightKg: 71.9,
              measuredAt: 1_767_229_200_000,
              timeZone: "America/Los_Angeles",
              version: 2,
            },
          }),
        ]);
      });

      test("取りに行くと、直した記録が1件にまとまって返ること", async () => {
        const pulled = await pullWeightRecordChanges(sessionToken);
        expect(pulled.changes).toHaveLength(1);
      });
    });

    describe("端末の時計で先の時刻の直しを先に、前の時刻の直しをあとに送ったとき", () => {
      let earlierOnDeviceClock: number;
      beforeEach(async () => {
        const now = Date.now();
        earlierOnDeviceClock = now - 3_600_000;
        await pushSyncWrites(sessionToken, {
          writes: [
            updateWeightRecordWrite(recordId, {
              weightRecord: { weightKg: 71.0, measuredAt: now },
            }),
          ],
        });
        await pushSyncWrites(sessionToken, {
          writes: [
            updateWeightRecordWrite(recordId, {
              weightRecord: { weightKg: 70.0, measuredAt: earlierOnDeviceClock },
            }),
          ],
        });
      });

      test("端末の時計によらず、あとに受け取ったほうの値を採ること", async () => {
        const pulled = await pullWeightRecordChanges(sessionToken);
        expect(pulled.changes[0]?.record).toEqual(
          expect.objectContaining({ weightKg: 70.0, measuredAt: earlierOnDeviceClock }),
        );
      });
    });

    describe("版 3 の直しのあとに、版 2 の直しを送ったとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, {
          writes: [updateWeightRecordWrite(recordId, { weightRecord: { version: 3 } })],
        });
        await pushSyncWrites(sessionToken, {
          writes: [
            updateWeightRecordWrite(recordId, { weightRecord: { weightKg: 70.0, version: 2 } }),
          ],
        });
      });

      test("あとに受け取った値を、前より大きい版 4 で採ること", async () => {
        const pulled = await pullWeightRecordChanges(sessionToken);
        expect(pulled.changes[0]?.record).toEqual(
          expect.objectContaining({ weightKg: 70.0, version: 4 }),
        );
      });
    });

    describe("版が 2 未満の直す書き込みを送ったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [updateWeightRecordWrite(recordId, { weightRecord: { version: 1 } })],
        });
      });

      test("受け付けないこと", async () => {
        expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe(
          "version_too_low",
        );
      });
    });

    describe("体重が範囲の外の直す書き込みを送ったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [updateWeightRecordWrite(recordId, { weightRecord: { weightKg: 300.1 } })],
        });
      });

      test("受け付けないこと", async () => {
        expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe(
          "out_of_range",
        );
      });
    });
  });

  describe("受け付けなかった書き込みに添える、サーバーの今の値", () => {
    let recordId: string;
    let measuredAt: number;
    beforeEach(async () => {
      // 使い始めた日より前の記録は直せないので、今の時刻で作る
      measuredAt = Date.now();
      const created = createWeightRecordWrite({
        weightRecord: { weightKg: 72.4, measuredAt, timeZone: "Asia/Tokyo" },
      });
      recordId = String(created.weightRecord["id"]);
      await pushSyncWrites(sessionToken, { writes: [created] });
    });

    describe("記録がある直す書き込みが受け付けられなかったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [updateWeightRecordWrite(recordId, { weightRecord: { version: 1 } })],
        });
      });

      test("その記録の今の値を、取りに行く変更と同じ形で添えること", async () => {
        expect((await response.json<PushResults>()).results[0]?.current).toEqual({
          status: "value",
          change: {
            kind: "weight_record",
            recordId,
            record: {
              id: recordId,
              weightKg: 72.4,
              measuredAt,
              timeZone: "Asia/Tokyo",
              version: 1,
            },
          },
        });
      });
    });

    describe("元のサンプルが消えて削除の印がある記録の直す書き込みが受け付けられなかったとき", () => {
      let response: Response;
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, { writes: [sourceDeletedWeightRecordWrite(recordId)] });
        response = await pushSyncWrites(sessionToken, {
          writes: [updateWeightRecordWrite(recordId, { weightRecord: { version: 1 } })],
        });
      });

      test("削除の印を、取りに行く変更と同じ形で添えること", async () => {
        expect((await response.json<PushResults>()).results[0]?.current).toEqual({
          status: "deleted",
          change: { kind: "weight_record_deletion", recordId, record: {} },
        });
      });
    });

    describe("記録の無い作る書き込みが受け付けられなかったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [createWeightRecordWrite({ weightRecord: { weightKg: 19.9 } })],
        });
      });

      test("無いことを、値とも削除の印とも見分けられる形で添えること", async () => {
        expect((await response.json<PushResults>()).results[0]?.current).toEqual({
          status: "absent",
        });
      });
    });

    describe("同じ要求で、同じ記録の直しが受け付けない、受け付けるの順に並んだとき", () => {
      let results: PushResults["results"];
      beforeEach(async () => {
        const response = await pushSyncWrites(sessionToken, {
          writes: [
            updateWeightRecordWrite(recordId, { weightRecord: { weightKg: 300.1 } }),
            updateWeightRecordWrite(recordId, { weightRecord: { weightKg: 70.0, version: 2 } }),
          ],
        });
        ({ results } = await response.json<PushResults>());
      });

      test("受け付けなかった書き込みには、あとの書き込みを当て終えた値を添えること", () => {
        expect(
          results.map(({ result, current }) => ({ result, current: current?.change?.record })),
        ).toEqual([
          {
            result: "rejected",
            current: expect.objectContaining({ id: recordId, weightKg: 70.0, version: 2 }),
          },
          { result: "applied", current: undefined },
        ]);
      });
    });

    describe("受け付けなかった書き込みの ID が、あとの直しのあとに再び届いたとき", () => {
      let rejected: ReturnType<typeof updateWeightRecordWrite>;
      let resent: PushResults["results"];
      beforeEach(async () => {
        rejected = updateWeightRecordWrite(recordId, { weightRecord: { weightKg: 300.1 } });
        await pushSyncWrites(sessionToken, { writes: [rejected] });
        await pushSyncWrites(sessionToken, {
          writes: [updateWeightRecordWrite(recordId, { weightRecord: { weightKg: 69.5 } })],
        });
        const response = await pushSyncWrites(sessionToken, { writes: [rejected] });
        ({ results: resent } = await response.json<PushResults>());
      });

      test("最初の結果の種類と理由を返すこと", () => {
        expect(resent[0]).toEqual(
          expect.objectContaining({
            result: "rejected",
            rejectionReason: "out_of_range",
          }),
        );
      });

      test("今の値は、この要求を当て終えた時点のものを添えること", () => {
        expect(resent[0]?.current?.change?.record).toEqual(
          expect.objectContaining({ weightKg: 69.5, version: 2 }),
        );
      });
    });
  });

  describe("知らない ID の体重記録を直す書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [updateWeightRecordWrite(generateRecordId())],
      });
    });

    test("受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe(
        "record_not_found",
      );
    });
  });

  describe("体重が 20.0 kg 未満の作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [createWeightRecordWrite({ weightRecord: { weightKg: 19.9 } })],
      });
    });

    test("範囲の外として受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe("out_of_range");
    });
  });

  describe("体脂肪率が範囲の外の作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      const write = createWeightRecordWrite({
        weightRecord: {
          imported: {
            sourceAppName: "Withings",
            sourceBundleId: "com.withings.wiScaleNG",
            healthkitSampleUuid: generateRecordId(),
            bodyFat: { percentage: 75.1, healthkitSampleUuid: generateRecordId() },
          },
        },
      });
      response = await pushSyncWrites(sessionToken, { writes: [write] });
    });

    test("範囲の外として受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe("out_of_range");
    });
  });

  describe("IANA の名前として読めないタイムゾーンの作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [createWeightRecordWrite({ weightRecord: { timeZone: "Mars/Olympus" } })],
      });
    });

    test("受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe(
        "invalid_time_zone",
      );
    });
  });

  describe("使い始める前の体重記録があるとき", () => {
    let recordId: string;
    beforeEach(async () => {
      const create = createWeightRecordWrite({
        weightRecord: { measuredAt: Date.UTC(2020, 0, 1) },
      });
      recordId = String(create.weightRecord["id"]);
      await pushSyncWrites(sessionToken, { writes: [create] });
    });

    test("作る書き込みで保存していること", async () => {
      const pulled = await pullWeightRecordChanges(sessionToken);
      expect(pulled.changes.map((change) => change.recordId)).toEqual([recordId]);
    });

    describe("直す書き込みを送ったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [updateWeightRecordWrite(recordId)],
        });
      });

      test("受け付けないこと", async () => {
        expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe(
          "record_before_started_on",
        );
      });
    });

    describe("使い始めた日がまだ無いとき", () => {
      let response: Response;
      beforeEach(async () => {
        await runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
          state.storage.sql.exec("DELETE FROM first_sign_ins"),
        );
        response = await pushSyncWrites(sessionToken, {
          writes: [updateWeightRecordWrite(recordId)],
        });
      });

      test("直す書き込みを当てること", async () => {
        expect((await response.json<PushResults>()).results[0]?.result).toBe("applied");
      });
    });
  });

  describe("直していない取り込みの体重記録の、元のサンプルが消えたという書き込みを送ったとき", () => {
    let imported: ReturnType<typeof createWeightRecordWrite>;
    let recordId: string;
    let deletion: ReturnType<typeof sourceDeletedWeightRecordWrite>;
    let response: Response;
    let created: PullResult;
    beforeEach(async () => {
      imported = createWeightRecordWrite({
        weightRecord: {
          imported: {
            sourceAppName: "Withings",
            sourceBundleId: "com.withings.wiScaleNG",
            healthkitSampleUuid: generateRecordId(),
            bodyFat: { percentage: 18.5, healthkitSampleUuid: generateRecordId() },
          },
        },
      });
      recordId = String(imported.weightRecord["id"]);
      await pushSyncWrites(sessionToken, { writes: [imported] });
      created = await pullWeightRecordChanges(sessionToken);
      deletion = sourceDeletedWeightRecordWrite(recordId);
      response = await pushSyncWrites(sessionToken, { writes: [deletion] });
    });

    test("消したと書き込みごとの結果を返すこと", async () => {
      expect({ status: response.status, body: await response.json() }).toEqual({
        status: 200,
        body: { results: [{ writeId: deletion.id, result: "applied" }] },
      });
    });

    test("前回の続きから取りに行くと、削除の印が返ること", async () => {
      const pulled = await pullWeightRecordChanges(sessionToken, {
        afterSequence: created.nextAfterSequence,
      });
      expect(pulled.changes).toEqual([
        {
          sequence: expect.any(Number),
          kind: "weight_record_deletion",
          recordId,
          record: {},
        },
      ]);
    });

    test("最初から取りに行くと、記録は返らず削除の印だけが返ること", async () => {
      const pulled = await pullWeightRecordChanges(sessionToken);
      expect(pulled.changes.map(({ kind, recordId: id }) => ({ kind, recordId: id }))).toEqual([
        { kind: "weight_record_deletion", recordId },
      ]);
    });

    test("取り込みの子の行も消えること", async () => {
      const rows = await readRows(
        accountId,
        `SELECT
           (SELECT COUNT(*) FROM weight_records) AS records,
           (SELECT COUNT(*) FROM imported_weight_records) AS imported_records,
           (SELECT COUNT(*) FROM imported_body_fat_percentages) AS body_fat_percentages`,
      );
      expect(rows).toEqual([{ records: 0, imported_records: 0, body_fat_percentages: 0 }]);
    });

    describe("同じ書き込みを送り直したとき", () => {
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, { writes: [deletion] });
      });

      test("最初の結果を返すこと", async () => {
        expect((await response.json<PushResults>()).results).toEqual([
          { writeId: deletion.id, result: "applied" },
        ]);
      });
    });

    describe("別の端末から、同じ記録の2つめの消えたという書き込みを送ったとき", () => {
      let secondResponse: Response;
      let latest: PullResult;
      beforeEach(async () => {
        const afterFirstDeletion = await pullWeightRecordChanges(sessionToken);
        secondResponse = await pushSyncWrites(sessionToken, {
          writes: [sourceDeletedWeightRecordWrite(recordId)],
        });
        latest = await pullWeightRecordChanges(sessionToken, {
          afterSequence: afterFirstDeletion.nextAfterSequence,
        });
      });

      test("捨てること", async () => {
        expect((await secondResponse.json<PushResults>()).results[0]?.result).toBe(
          "ignored_tombstone",
        );
      });

      test("削除の印を、次に取りに行った端末に返し直すこと", () => {
        expect(latest.changes.map(({ kind, recordId: id }) => ({ kind, recordId: id }))).toEqual([
          { kind: "weight_record_deletion", recordId },
        ]);
      });
    });

    describe("削除の印がある ID への作る書き込みを送ったとき", () => {
      let recreateResponse: Response;
      let latest: PullResult;
      beforeEach(async () => {
        const afterDeletion = await pullWeightRecordChanges(sessionToken);
        recreateResponse = await pushSyncWrites(sessionToken, {
          writes: [
            createWeightRecordWrite({ weightRecord: { id: recordId, imported: undefined } }),
          ],
        });
        latest = await pullWeightRecordChanges(sessionToken, {
          afterSequence: afterDeletion.nextAfterSequence,
        });
      });

      test("捨てること", async () => {
        expect((await recreateResponse.json<PushResults>()).results[0]?.result).toBe(
          "ignored_tombstone",
        );
      });

      test("記録を生き返らせず、削除の印を返し直すこと", () => {
        expect(latest.changes.map(({ kind, recordId: id }) => ({ kind, recordId: id }))).toEqual([
          { kind: "weight_record_deletion", recordId },
        ]);
      });
    });

    describe("削除の印がある ID への直す書き込みを送ったとき", () => {
      let updateResponse: Response;
      let latest: PullResult;
      beforeEach(async () => {
        const afterDeletion = await pullWeightRecordChanges(sessionToken);
        updateResponse = await pushSyncWrites(sessionToken, {
          writes: [updateWeightRecordWrite(recordId)],
        });
        latest = await pullWeightRecordChanges(sessionToken, {
          afterSequence: afterDeletion.nextAfterSequence,
        });
      });

      test("捨てること", async () => {
        expect((await updateResponse.json<PushResults>()).results[0]?.result).toBe(
          "ignored_tombstone",
        );
      });

      test("削除の印を返し直すこと", () => {
        expect(latest.changes.map(({ kind, recordId: id }) => ({ kind, recordId: id }))).toEqual([
          { kind: "weight_record_deletion", recordId },
        ]);
      });
    });
  });

  describe("直した体重記録の、元のサンプルが消えたという書き込みを送ったとき", () => {
    let recordId: string;
    let deletion: ReturnType<typeof sourceDeletedWeightRecordWrite>;
    let response: Response;
    let corrected: PullResult;
    beforeEach(async () => {
      const create = createWeightRecordWrite({
        weightRecord: {
          imported: {
            sourceAppName: "Withings",
            sourceBundleId: "com.withings.wiScaleNG",
            healthkitSampleUuid: generateRecordId(),
          },
        },
      });
      recordId = String(create.weightRecord["id"]);
      await pushSyncWrites(sessionToken, { writes: [create, updateWeightRecordWrite(recordId)] });
      corrected = await pullWeightRecordChanges(sessionToken);
      deletion = sourceDeletedWeightRecordWrite(recordId);
      response = await pushSyncWrites(sessionToken, { writes: [deletion] });
    });

    test("残したと返すこと", async () => {
      expect((await response.json<PushResults>()).results).toEqual([
        { writeId: deletion.id, result: "kept_corrected" },
      ]);
    });

    test("記録をそのまま残し、変更を増やさないこと", async () => {
      const pulled = await pullWeightRecordChanges(sessionToken);
      expect(pulled).toEqual({ ...corrected, startedOn: expect.any(String) });
    });

    describe("同じ書き込みを送り直したとき", () => {
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, { writes: [deletion] });
      });

      test("最初の結果を返すこと", async () => {
        expect((await response.json<PushResults>()).results[0]?.result).toBe("kept_corrected");
      });
    });
  });

  describe("使い始める前の体重記録の、元のサンプルが消えたという書き込みを送ったとき", () => {
    let recordId: string;
    let response: Response;
    beforeEach(async () => {
      const create = createWeightRecordWrite({
        weightRecord: { measuredAt: Date.UTC(2020, 0, 1) },
      });
      recordId = String(create.weightRecord["id"]);
      await pushSyncWrites(sessionToken, { writes: [create] });
      response = await pushSyncWrites(sessionToken, {
        writes: [sourceDeletedWeightRecordWrite(recordId)],
      });
    });

    test("消すこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.result).toBe("applied");
    });

    test("削除の印を返すこと", async () => {
      const pulled = await pullWeightRecordChanges(sessionToken);
      expect(pulled.changes.map(({ kind }) => kind)).toEqual(["weight_record_deletion"]);
    });
  });

  describe("知らない ID の、元のサンプルが消えたという書き込みを送ったとき", () => {
    let recordId: string;
    let response: Response;
    beforeEach(async () => {
      recordId = generateRecordId();
      response = await pushSyncWrites(sessionToken, {
        writes: [sourceDeletedWeightRecordWrite(recordId)],
      });
    });

    test("削除の印を残すこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.result).toBe("applied");
      const pulled = await pullWeightRecordChanges(sessionToken);
      expect(pulled.changes.map(({ kind, recordId: id }) => ({ kind, recordId: id }))).toEqual([
        { kind: "weight_record_deletion", recordId },
      ]);
    });

    describe("あとから、その ID の作る書き込みが届いたとき", () => {
      let createResponse: Response;
      beforeEach(async () => {
        createResponse = await pushSyncWrites(sessionToken, {
          writes: [createWeightRecordWrite({ weightRecord: { id: recordId } })],
        });
      });

      test("捨てて、消えた体重を生き返らせないこと", async () => {
        expect((await createResponse.json<PushResults>()).results[0]?.result).toBe(
          "ignored_tombstone",
        );
        const pulled = await pullWeightRecordChanges(sessionToken);
        expect(pulled.changes.map(({ kind }) => kind)).toEqual(["weight_record_deletion"]);
      });
    });
  });
});
