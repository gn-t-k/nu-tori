import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import {
  mockPostHogCaptureEndpointError,
  mockPostHogCaptureEndpointOk,
  mockPostHogCaptureEndpointUnreachable,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { signInTestAccount } from "../testing";
import { createWeightRecordWrite } from "./testing/create-weight-record-write";
import { enableUsageEventSending } from "./testing/enable-usage-event-sending";
import { pullSyncChanges } from "./testing/pull-sync-changes";
import { pushSyncWrites } from "./testing/push-sync-writes";
import { updateAccountSettingsWrite } from "./testing/update-account-settings-write";

type PushResults = {
  results: { writeId: string; result: string; rejectionReason?: string }[];
};
type PullResult = {
  changes: { sequence: number; kind: string; recordId: string; record: Record<string, unknown> }[];
};

describe("利用状況を送るかのアカウントの設定", () => {
  let accountId: string;
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(crypto.randomUUID()));
  });

  describe("記録が無いときに切り替える書き込みを送ったとき", () => {
    let write: ReturnType<typeof updateAccountSettingsWrite>;
    let response: Response;
    beforeEach(async () => {
      write = updateAccountSettingsWrite({ accountSettings: { sendsUsageData: false } });
      response = await pushSyncWrites(sessionToken, { writes: [write] });
    });

    test("当てたと返すこと", async () => {
      expect((await response.json<PushResults>()).results).toEqual([
        { writeId: write.id, result: "applied" },
      ]);
    });

    test("取りに行くと、アカウントの設定が返ること", async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      expect(pulled.changes).toEqual([
        {
          sequence: expect.any(Number),
          kind: "account_settings",
          recordId: "account-settings-1",
          record: { id: "account-settings-1", sendsUsageData: false },
        },
      ]);
    });

    test("切り替えたあとの値を控えること", async () => {
      expect(
        await readRows(accountId, "SELECT sends_usage_data FROM account_setting_changes"),
      ).toEqual([{ sends_usage_data: 0 }]);
    });
  });

  describe("記録があるときに、あとから切り替える書き込みを送ったとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, {
        writes: [updateAccountSettingsWrite({ accountSettings: { sendsUsageData: false } })],
      });
      await pushSyncWrites(sessionToken, {
        writes: [updateAccountSettingsWrite({ accountSettings: { sendsUsageData: true } })],
      });
    });

    test("あとに受け取ったほうの値を1件だけ返すこと", async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      expect(pulled.changes.map(({ record }) => record["sendsUsageData"])).toEqual([true]);
    });

    test("切り替えのたびに控えること", async () => {
      expect(
        await readRows(accountId, "SELECT sends_usage_data FROM account_setting_changes"),
      ).toEqual([{ sends_usage_data: 0 }, { sends_usage_data: 1 }]);
    });
  });

  describe("端末が振った ID が、記録の ID と違う切り替えを送ったとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, {
        writes: [updateAccountSettingsWrite({ accountSettings: { id: "first-device" } })],
      });
      await pushSyncWrites(sessionToken, {
        writes: [
          updateAccountSettingsWrite({
            accountSettings: { id: "second-device", sendsUsageData: true },
          }),
        ],
      });
    });

    test("アカウントの設定を1件のまま置き換えること", async () => {
      expect(
        await readRows(accountId, "SELECT id, sends_usage_data FROM account_settings"),
      ).toEqual([{ id: "first-device", sends_usage_data: 1 }]);
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

    test("受け付けなかった書き込みを送らないこと", async () => {
      await pushSyncWrites(sessionToken, {
        writes: [createWeightRecordWrite({ weightRecord: { weightKg: 5000 } })],
      });
      expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
    });

    test("送り待ちの数を送らないこと", async () => {
      await pullSyncChanges(sessionToken, { clientState: { oldestPendingWriteAgeSeconds: 7200 } });
      expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
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

  describe("送り直された、受け付けなかった書き込みを送ったとき", () => {
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

  describe("PostHog に送れないとき", () => {
    let write: ReturnType<typeof createWeightRecordWrite>;
    beforeEach(async () => {
      write = createWeightRecordWrite();
      await enableUsageEventSending(accountId);
    });

    test("つながらなくても、書き込みを当てること", async () => {
      mockPostHogCaptureEndpointUnreachable();
      const response = await pushSyncWrites(sessionToken, {
        writes: [write, createWeightRecordWrite({ weightRecord: { weightKg: 5000 } })],
      });
      expect((await response.json<PushResults>()).results[0]?.result).toBe("applied");
    });

    test("エラーを返されても、書き込みを当てること", async () => {
      mockPostHogCaptureEndpointError(500);
      const response = await pushSyncWrites(sessionToken, {
        writes: [write, createWeightRecordWrite({ weightRecord: { weightKg: 5000 } })],
      });
      expect((await response.json<PushResults>()).results[0]?.result).toBe("applied");
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

      test("同じ日の2つめの要求では送らないこと", async () => {
        fetchSpy.mockClear();
        await pullSyncChanges(sessionToken, {
          clientState: { oldestPendingWriteAgeSeconds: 7200 },
        });
        expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
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
});

const readRows = (accountId: string, query: string) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
    state.storage.sql.exec(query).toArray(),
  );

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
