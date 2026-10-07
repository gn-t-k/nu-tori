import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../../domain/record-id";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import type { AccountSettingsStore } from "../domain/account-settings-store";
import { createAccountSettingsStore } from "./create-account-settings-store";

const settings1 = generateRecordId();

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
        store.insert({ id: settings1, sendsUsageData: true });
        return store.find();
      });
      expect(found).toEqual({ id: settings1, sendsUsageData: true });
    });
  });

  describe("設定があるとき", () => {
    let seed: Seed;
    beforeEach(() => {
      seed = async (factory) => {
        await factory.accountSettings.create({ id: settings1, sendsUsageData: false });
      };
    });

    test("ID とともに今の値を読めること", async () => {
      const found = await withStore(seed, (store) => store.find());
      expect(found).toEqual({ id: settings1, sendsUsageData: false });
    });

    test("値を直すと、ID は変わらず値だけが変わること", async () => {
      const found = await withStore(seed, (store) => {
        store.update(true);
        return store.find();
      });
      expect(found).toEqual({ id: settings1, sendsUsageData: true });
    });
  });
});
