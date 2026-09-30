import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { signInTestAccount } from "../testing";
import { updateAccountSettingsWrite } from "../../account-settings/http/testing/update-account-settings-write";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import {
  mockPostHogCaptureEndpointError,
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";
import { app } from "../app";
import { enableUsageEventSending } from "./testing/enable-usage-event-sending";
import { pullSyncChanges } from "./testing/pull-sync-changes";
import { pushSyncWrites } from "./testing/push-sync-writes";
import { readRows } from "./testing/read-rows";
import type { PullResult, PushResults } from "./testing/sync-response";
import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";

describe("同期", () => {
  let accountId: string;
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(crypto.randomUUID()));
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

  describe("本番のサーバーで、記録が無いまま受け付けなかった書き込みを送ったとき", () => {
    let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      fetchSpy = mockPostHogCaptureEndpointOk();
      await pushSyncWrites(sessionToken, {
        writes: [createWeightRecordWrite({ weightRecord: { weightKg: 5000 } })],
      });
    });

    test("既定のオンとして、受け付けなかった書き込みの種類と理由を PostHog に送ること", () => {
      expect(readPostHogCapturedEvents(fetchSpy)).toEqual([
        {
          event: "sync_write_rejected",
          distinct_id: accountId,
          properties: {
            write_kind: "create",
            record_type: "weight_record",
            reason: "out_of_range",
            $geoip_disable: true,
          },
        },
      ]);
    });

    test("体重の値を送らないこと", () => {
      expect(JSON.stringify(readPostHogCapturedEvents(fetchSpy))).not.toContain("5000");
    });

    test("時間の上限を付けて送ること", () => {
      expect(fetchSpy.mock.calls.at(-1)?.[1]?.signal).toBeInstanceOf(AbortSignal);
    });
  });

  describe("本番のサーバーで、利用状況を送らない設定のとき", () => {
    let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, { writes: [updateAccountSettingsWrite()] });
      await enableUsageEventSending(accountId);
      fetchSpy = mockPostHogCaptureEndpointOk();
    });

    describe("受け付けなかった書き込みを送ったとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, {
          writes: [createWeightRecordWrite({ weightRecord: { weightKg: 5000 } })],
        });
      });

      test("PostHog に送らないこと", () => {
        expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
      });
    });

    describe("いちばん古い送り待ちが1時間を超えた状態で取りに行ったとき", () => {
      beforeEach(async () => {
        await pullSyncChanges(sessionToken, {
          clientState: { oldestPendingWriteAgeSeconds: 7200 },
        });
      });

      test("PostHog に送らないこと", () => {
        expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
      });
    });

    describe("オンに戻す書き込みと、受け付けなかった書き込みを同じ要求で送ったとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, {
          writes: [
            updateAccountSettingsWrite({ accountSettings: { sendsUsageData: true } }),
            createWeightRecordWrite({ weightRecord: { weightKg: 5000 } }),
          ],
        });
      });

      test("書き込みを当てたあとの設定に従い、その要求の分から送ること", () => {
        expect(readPostHogCapturedEvents(fetchSpy).map(({ event }) => event)).toEqual([
          "sync_write_rejected",
        ]);
      });
    });
  });

  describe("本番のサーバーで、オフに切り替える書き込みと受け付けなかった書き込みを同じ要求で送ったとき", () => {
    let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      fetchSpy = mockPostHogCaptureEndpointOk();
      await pushSyncWrites(sessionToken, {
        writes: [
          createWeightRecordWrite({ weightRecord: { weightKg: 5000 } }),
          updateAccountSettingsWrite(),
        ],
      });
    });

    test("書き込みを当てたときから送らないこと", () => {
      expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
    });
  });

  describe("本番のサーバーで、受け付けなかった書き込みを送り直したとき", () => {
    let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      const write = createWeightRecordWrite({ weightRecord: { weightKg: 5000 } });
      await enableUsageEventSending(accountId);
      fetchSpy = mockPostHogCaptureEndpointOk();
      await pushSyncWrites(sessionToken, { writes: [write] });
      fetchSpy.mockClear();
      await pushSyncWrites(sessionToken, { writes: [write] });
    });

    test("もう一度は送らないこと", () => {
      expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
    });
  });

  describe("開発用のサーバーで、受け付けなかった書き込みを送ったとき", () => {
    let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      fetchSpy = mockPostHogCaptureEndpointOk();
      await pushSyncWrites(sessionToken, {
        writes: [createWeightRecordWrite({ weightRecord: { weightKg: 5000 } })],
      });
    });

    test("PostHog に送らないこと", () => {
      expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
    });
  });

  describe("本番のサーバーで、PostHog につながらないとき", () => {
    let response: Response;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      mockPostHogCaptureEndpointError(new TypeError("Network connection lost"));
      response = await pushSyncWrites(sessionToken, {
        writes: [
          createWeightRecordWrite(),
          createWeightRecordWrite({ weightRecord: { weightKg: 5000 } }),
        ],
      });
    });

    test("書き込みを当てること", async () => {
      expect((await response.json<PushResults>()).results.map(({ result }) => result)).toEqual([
        "applied",
        "rejected",
      ]);
    });
  });

  describe("本番のサーバーで、PostHog がエラーを返すとき", () => {
    let response: Response;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      mockPostHogCaptureEndpointError(500);
      response = await pushSyncWrites(sessionToken, {
        writes: [
          createWeightRecordWrite(),
          createWeightRecordWrite({ weightRecord: { weightKg: 5000 } }),
        ],
      });
    });

    test("書き込みを当てること", async () => {
      expect((await response.json<PushResults>()).results.map(({ result }) => result)).toEqual([
        "applied",
        "rejected",
      ]);
    });
  });

  describe("本番のサーバーで、送り待ちの数を添えた要求を送ったとき", () => {
    let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      fetchSpy = mockPostHogCaptureEndpointOk();
    });

    describe("その日の最初の要求で、いちばん古い送り待ちが1時間を超えているとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, {
          writes: [],
          clientState: { pendingWriteCount: 12, oldestPendingWriteAgeSeconds: 7200 },
        });
      });

      test("送り待ちの数といちばん古い経過時間を送ること", () => {
        expect(readPostHogCapturedEvents(fetchSpy)).toEqual([
          {
            event: "sync_pending_writes_reported",
            distinct_id: accountId,
            properties: {
              pending_write_count: 12,
              oldest_pending_write_age_seconds: 7200,
              $geoip_disable: true,
            },
          },
        ]);
      });

      describe("同じ日の2つめの要求を取りに行ったとき", () => {
        beforeEach(async () => {
          fetchSpy.mockClear();
          await pullSyncChanges(sessionToken, {
            clientState: { oldestPendingWriteAgeSeconds: 7200 },
          });
        });

        test("送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });
    });

    describe("その日の最初の要求で、いちばん古い送り待ちが1時間ちょうどのとき", () => {
      beforeEach(async () => {
        await pullSyncChanges(sessionToken, {
          clientState: { oldestPendingWriteAgeSeconds: 3600 },
        });
      });

      test("送らないこと", () => {
        expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
      });
    });

    describe("送り待ちが無いとき", () => {
      beforeEach(async () => {
        await pullSyncChanges(sessionToken, {
          clientState: { pendingWriteCount: 0, oldestPendingWriteAgeSeconds: undefined },
        });
      });

      test("送らないこと", () => {
        expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
      });
    });

    describe("同じ日の2つめの要求で、いちばん古い送り待ちが1時間を超えているとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, { writes: [] });
        await pushSyncWrites(sessionToken, {
          writes: [],
          clientState: { oldestPendingWriteAgeSeconds: 7200 },
        });
      });

      test("送らないこと", () => {
        expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
      });
    });

    describe("前の要求が前の日で、いちばん古い送り待ちが1時間を超えているとき", () => {
      beforeEach(async () => {
        await insertRequestLog(accountId, Date.now() - 2 * 24 * 60 * 60 * 1000);
        await pullSyncChanges(sessionToken, {
          clientState: { oldestPendingWriteAgeSeconds: 7200 },
        });
      });

      test("取りに行く要求でも送ること", () => {
        expect(readPostHogCapturedEvents(fetchSpy).map(({ event }) => event)).toEqual([
          "sync_pending_writes_reported",
        ]);
      });
    });

    describe("要求のタイムゾーンが IANA の名前として読めないとき", () => {
      beforeEach(async () => {
        await pullSyncChanges(sessionToken, {
          clientState: { timeZone: "Mars/Olympus", oldestPendingWriteAgeSeconds: 7200 },
        });
      });

      test("その日の最初かを決められないので送らないこと", () => {
        expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
      });
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

const insertRequestLog = (accountId: string, receivedAt: number) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
    state.storage.sql.exec(
      `INSERT INTO sync_request_logs
         (id, device_id, received_at, time_zone, app_version, os_version,
          pending_write_count, oldest_pending_write_age_seconds, pending_photo_count)
       VALUES (?, 'device-1', ?, 'Asia/Tokyo', '1.0.0', '26.0', 0, NULL, 0)`,
      crypto.randomUUID(),
      receivedAt,
    ),
  );
