import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { signInTestAccount } from "../../http/testing";
import { pullSyncChanges } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import type { PullResult, PushResults } from "../../http/sync-routes/testing/sync-response";
import { updateAccountSettingsWrite } from "./testing/update-account-settings-write";
import { beforeEach, describe, expect, test } from "vitest";

describe("アカウントの設定の同期", () => {
  let accountId: string;
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(crypto.randomUUID()));
  });

  describe("記録が無いときに、利用状況を切り替える書き込みを送ったとき", () => {
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

  describe("記録があるときに、あとから利用状況を切り替える書き込みを送ったとき", () => {
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
});
