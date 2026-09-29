import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { app } from "../app";
import { signInTestAccount } from "../testing";
import { createWeightRecordWrite } from "./testing/create-weight-record-write";
import { pullSyncChanges } from "./testing/pull-sync-changes";
import { pushSyncWrites } from "./testing/push-sync-writes";
import { updateWeightRecordWrite } from "./testing/update-weight-record-write";

describe("同期", () => {
  let accountId: string;
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(crypto.randomUUID()));
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
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
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
            healthkitSampleUuid: crypto.randomUUID(),
            bodyFat: { percentage: 18.5, healthkitSampleUuid: crypto.randomUUID() },
          },
        },
      });
      await pushSyncWrites(sessionToken, { writes: [write] });
    });

    test("出どころと体脂肪率も返ること", async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
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

  describe("同じ書き込みを送り直したとき", () => {
    let write: ReturnType<typeof createWeightRecordWrite>;
    let resent: Response;
    beforeEach(async () => {
      write = createWeightRecordWrite();
      await pushSyncWrites(sessionToken, { writes: [write] });
      resent = await pushSyncWrites(sessionToken, { writes: [write] });
    });

    test("最初の結果を返すこと", async () => {
      expect((await resent.json<PushResults>()).results).toEqual([
        { writeId: write.id, result: "applied" },
      ]);
    });

    test("記録も変更も増えないこと", async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      expect(pulled.changes).toHaveLength(1);
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
        const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
        expect(pulled.changes[0]?.record["weightKg"]).toBe(72.4);
      });
    });
  });

  describe("同じ要求の中に同じ書き込みの ID が2回あるとき", () => {
    let response: Response;
    beforeEach(async () => {
      const first = createWeightRecordWrite();
      const second = createWeightRecordWrite({ id: first.id, weightRecord: { weightKg: 500 } });
      response = await pushSyncWrites(sessionToken, { writes: [first, second] });
    });

    test("2回目は最初の結果になること", async () => {
      expect((await response.json<PushResults>()).results.map(({ result }) => result)).toEqual([
        "applied",
        "applied",
      ]);
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
        const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
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
        const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
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
        const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
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
        const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
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

  describe("知らない ID の体重記録を直す書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [updateWeightRecordWrite(crypto.randomUUID())],
      });
    });

    test("受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe(
        "record_not_found",
      );
    });
  });

  describe("受け付けない書き込みが混じった要求を送ったとき", () => {
    let tooHeavy: ReturnType<typeof createWeightRecordWrite>;
    let acceptable: ReturnType<typeof createWeightRecordWrite>;
    let results: PushResults["results"];
    beforeEach(async () => {
      tooHeavy = createWeightRecordWrite({ weightRecord: { weightKg: 300.1 } });
      acceptable = createWeightRecordWrite();
      const response = await pushSyncWrites(sessionToken, { writes: [tooHeavy, acceptable] });
      ({ results } = await response.json<PushResults>());
    });

    test("受け付けない書き込みに理由を添え、ほかの書き込みは当てること", () => {
      expect(results).toEqual([
        { writeId: tooHeavy.id, result: "rejected", rejectionReason: "out_of_range" },
        { writeId: acceptable.id, result: "applied" },
      ]);
    });

    test("受け付けなかった記録は保存しないこと", async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      expect(pulled.changes.map(({ recordId }) => recordId)).toEqual([
        acceptable.weightRecord["id"],
      ]);
    });

    describe("受け付けなかった書き込みを送り直したとき", () => {
      let resent: Response;
      beforeEach(async () => {
        resent = await pushSyncWrites(sessionToken, { writes: [tooHeavy] });
      });

      test("最初の結果を返すこと", async () => {
        expect((await resent.json<PushResults>()).results).toEqual([results[0]]);
      });
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
            healthkitSampleUuid: crypto.randomUUID(),
            bodyFat: { percentage: 75.1, healthkitSampleUuid: crypto.randomUUID() },
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
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
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

  describe("送る要求の書き込みが 500 件のとき", () => {
    let response: Response;
    beforeEach(async () => {
      const writes = Array.from({ length: 500 }, () => createWeightRecordWrite());
      response = await pushSyncWrites(sessionToken, { writes });
    });

    test("すべて当てること", async () => {
      expect(
        (await response.json<PushResults>()).results.every(({ result }) => result === "applied"),
      ).toBe(true);
    });
  });

  describe("送る要求の書き込みが 501 件のとき", () => {
    let response: Response;
    beforeEach(async () => {
      const writes = Array.from({ length: 501 }, () => createWeightRecordWrite());
      response = await pushSyncWrites(sessionToken, { writes });
    });

    test("400 を返すこと", () => {
      expect(response.status).toBe(400);
    });

    test("何も当てず、要求の控えも書かないこと", async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      const requestLogs = await readRows(
        accountId,
        "SELECT sync_request_log_id FROM sync_push_logs",
      );
      expect({ changes: pulled.changes, pushRequestLogs: requestLogs }).toEqual({
        changes: [],
        pushRequestLogs: [],
      });
    });
  });

  describe("502 件の体重記録があるとき", () => {
    let first: PullResult;
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, {
        writes: Array.from({ length: 500 }, () => createWeightRecordWrite()),
      });
      await pushSyncWrites(sessionToken, {
        writes: Array.from({ length: 2 }, () => createWeightRecordWrite()),
      });
      first = await (await pullSyncChanges(sessionToken)).json<PullResult>();
    });

    test("取りに行くと、1回の応答を 500 件で切り、続きがあると添えること", () => {
      expect({ count: first.changes.length, hasMore: first.hasMore }).toEqual({
        count: 500,
        hasMore: true,
      });
    });

    describe("次の続きから取りに行ったとき", () => {
      let second: PullResult;
      beforeEach(async () => {
        second = await (
          await pullSyncChanges(sessionToken, { afterSequence: first.nextAfterSequence })
        ).json<PullResult>();
      });

      test("残りを返し、続きが無いと添えること", () => {
        expect({ count: second.changes.length, hasMore: second.hasMore }).toEqual({
          count: 2,
          hasMore: false,
        });
      });

      describe("最後の続きから取りに行ったとき", () => {
        let third: PullResult;
        beforeEach(async () => {
          third = await (
            await pullSyncChanges(sessionToken, { afterSequence: second.nextAfterSequence })
          ).json<PullResult>();
        });

        test("何も返さず、続きを進めないこと", () => {
          expect(third).toEqual({
            changes: [],
            hasMore: false,
            nextAfterSequence: second.nextAfterSequence,
            startedOn: expect.any(String),
          });
        });
      });
    });
  });

  describe("使い始めた日が決まっているとき", () => {
    test("取りに行く応答に載ること", async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      expect(pulled.startedOn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    });
  });

  describe("使い始めた日がまだ決まっていないとき", () => {
    let pulled: PullResult;
    beforeEach(async () => {
      await runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
        state.storage.sql.exec("DELETE FROM first_sign_ins"),
      );
      pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
    });

    test("取りに行く応答で null を返すこと", () => {
      expect(pulled.startedOn).toBeNull();
    });
  });

  describe("送る要求に端末の状態が添えられているとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, {
        writes: [createWeightRecordWrite()],
        isFinalBatch: true,
        clientState: {
          deviceId: "device-a",
          timeZone: "Asia/Tokyo",
          appVersion: "1.2.3",
          osVersion: "26.1",
          pendingWriteCount: 7,
          oldestPendingWriteAgeSeconds: 3600,
          pendingPhotoCount: 2,
        },
      });
    });

    test("端末の状態と送り切った印を控えること", async () => {
      const rows = await readRows(
        accountId,
        `SELECT log.device_id, log.time_zone, log.app_version, log.os_version,
                log.pending_write_count, log.oldest_pending_write_age_seconds,
                log.pending_photo_count, push.is_final_batch
         FROM sync_request_logs AS log
         JOIN sync_push_logs AS push ON push.sync_request_log_id = log.id`,
      );
      expect(rows).toEqual([
        {
          device_id: "device-a",
          time_zone: "Asia/Tokyo",
          app_version: "1.2.3",
          os_version: "26.1",
          pending_write_count: 7,
          oldest_pending_write_age_seconds: 3600,
          pending_photo_count: 2,
          is_final_batch: 1,
        },
      ]);
    });
  });

  describe("取りに行く要求に、送り待ちが無い端末の状態が添えられているとき", () => {
    beforeEach(async () => {
      await pullSyncChanges(sessionToken, {
        afterSequence: 0,
        clientState: {
          timeZone: "America/Los_Angeles",
          pendingWriteCount: 0,
          oldestPendingWriteAgeSeconds: undefined,
        },
      });
    });

    test("端末の状態と前回の続きを、経過時間なしで控えること", async () => {
      const rows = await readRows(
        accountId,
        `SELECT log.time_zone, log.pending_write_count, log.oldest_pending_write_age_seconds,
                pull.after_change_sequence
         FROM sync_request_logs AS log
         JOIN sync_pull_logs AS pull ON pull.sync_request_log_id = log.id`,
      );
      expect(rows).toEqual([
        {
          time_zone: "America/Los_Angeles",
          pending_write_count: 0,
          oldest_pending_write_age_seconds: null,
          after_change_sequence: 0,
        },
      ]);
    });
  });

  describe("タイムゾーンの違う要求を続けて送ったとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, { writes: [], clientState: { timeZone: "Asia/Tokyo" } });
      await pullSyncChanges(sessionToken, { clientState: { timeZone: "America/Los_Angeles" } });
    });

    test("ユーザーのタイムゾーンを、届いた最新の控えから出せること", async () => {
      const rows = await readRows(
        accountId,
        "SELECT time_zone FROM sync_request_logs ORDER BY received_at DESC, rowid DESC LIMIT 1",
      );
      expect(rows).toEqual([{ time_zone: "America/Los_Angeles" }]);
    });
  });

  describe("要求のタイムゾーンが IANA の名前として読めないとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [createWeightRecordWrite()],
        clientState: { timeZone: "Mars/Olympus" },
      });
    });

    test("書き込みを当てること", async () => {
      expect((await response.json<PushResults>()).results[0]?.result).toBe("applied");
    });

    test("読めない名前を、届いたまま控えること", async () => {
      const rows = await readRows(accountId, "SELECT time_zone FROM sync_request_logs");
      expect(rows).toEqual([{ time_zone: "Mars/Olympus" }]);
    });
  });

  describe("セッションが無いとき", () => {
    test("送る要求に 401 を返すこと", async () => {
      const response = await app.request(
        "/v1/sync/writes",
        { method: "POST", headers: { "content-type": "application/json" }, body: "{}" },
        env,
      );
      expect(response.status).toBe(401);
    });

    test("取りに行く要求に 401 を返すこと", async () => {
      const response = await app.request("/v1/sync/changes", {}, env);
      expect(response.status).toBe(401);
    });
  });
});

const readRows = (accountId: string, query: string) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
    state.storage.sql.exec(query).toArray(),
  );

type PushResults = {
  results: { writeId: string; result: string; rejectionReason?: string }[];
};
type PullResult = {
  changes: { sequence: number; kind: string; recordId: string; record: Record<string, unknown> }[];
  hasMore: boolean;
  nextAfterSequence: number;
  startedOn: string | null;
};
