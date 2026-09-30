import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { createSyncLedger } from "../../domain/sync-ledger/sync-ledger";
import { createLedgerStore } from "../../durable-object/create-ledger-store";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { createAccountSettingsKind } from "../domain/create-account-settings-kind";
import type { RecordType } from "../../domain/record-type";
import type { AccountSettings } from "../domain/account-settings";
import type { AccountSettingsStore } from "../domain/account-settings-store";
import type { AccountSettingsWrite } from "../domain/account-settings-write";
import { accountSettingsTables } from "./account-settings-tables";
import { createAccountSettingsStore } from "./create-account-settings-store";

type Seed = (factory: ReturnType<typeof durableObjectFactory>) => Promise<void>;

// 行は factory で作り、置き場の読み書きを実物の Durable Object の中で確かめる
const withStore = <T>(seed: Seed, run: (store: AccountSettingsStore) => T): Promise<T> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), async (_, state) => {
    await seed(durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })));
    return run(createAccountSettingsStore(drizzle(state.storage)));
  });

describe("アカウントの設定の置き場", () => {
  describe("設定が無いとき", () => {
    let seed: Seed;
    beforeEach(() => {
      seed = async () => undefined;
    });

    test("読むと何も返さないこと", async () => {
      expect(await withStore(seed, (store) => store.find())).toBeUndefined();
    });

    test("入れた設定を読めること", async () => {
      const found = await withStore(seed, (store) => {
        store.insert({ id: "settings-1", sendsUsageData: true });
        return store.find();
      });
      expect(found).toEqual({ id: "settings-1", sendsUsageData: true });
    });
  });

  describe("設定があるとき", () => {
    let seed: Seed;
    beforeEach(() => {
      seed = async (factory) => {
        await factory.accountSettings.create({ id: "settings-1", sendsUsageData: false });
      };
    });

    test("ID とともに今の値を読めること", async () => {
      const found = await withStore(seed, (store) => store.find());
      expect(found).toEqual({ id: "settings-1", sendsUsageData: false });
    });

    test("値を直すと、ID は変わらず値だけが変わること", async () => {
      const found = await withStore(seed, (store) => {
        store.update(true);
        return store.find();
      });
      expect(found).toEqual({ id: "settings-1", sendsUsageData: true });
    });
  });

  describe("設定を切り替える書き込みを帳簿に通したとき", () => {
    test("切り替えたあとの値を、書き込みの控えに紐づけて残すこと", async () => {
      const changes = await runInDurableObject(
        env.ACCOUNT.get(env.ACCOUNT.newUniqueId()),
        async (_, state) => {
          const db = drizzle(state.storage);
          // 控えの ID は帳簿しか作れないので、帳簿を通して置き場に渡す
          createSyncLedger<RecordType, "account_settings", AccountSettingsWrite, AccountSettings>(
            createLedgerStore(state.storage),
            [createAccountSettingsKind(createAccountSettingsStore(db))],
          ).push({
            clientState: {
              deviceId: "device-1",
              timeZone: "Asia/Tokyo",
              appVersion: "1.0.0",
              osVersion: "26.0",
              pendingWriteCount: 0,
              oldestPendingWriteAgeSeconds: undefined,
              pendingPhotoCount: 0,
            },
            writes: [
              {
                id: "write-1",
                type: "update_account_settings",
                accountSettings: { id: "settings-1", sendsUsageData: true },
              },
            ],
            isFinalBatch: true,
            receivedAt: new Date("2026-01-01T00:00:00Z"),
          });
          return db.select().from(accountSettingsTables.accountSettingChanges).all();
        },
      );
      expect(changes).toEqual([{ syncWriteReceiptId: "write-1", sendsUsageData: true }]);
    });
  });
});
