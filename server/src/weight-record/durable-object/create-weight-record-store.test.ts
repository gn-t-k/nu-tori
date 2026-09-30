import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import type { WeightRecordStore } from "../domain/weight-record-store";
import { createWeightRecordStore } from "./create-weight-record-store";

type Seed = (factory: ReturnType<typeof durableObjectFactory>) => Promise<void>;

// 行は factory で作り、置き場の読み取りを実物の Durable Object の中で確かめる
const withStore = <T>(seed: Seed, read: (store: WeightRecordStore) => T): Promise<T> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), async (_, state) => {
    await seed(durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })));
    return read(createWeightRecordStore(drizzle(state.storage)));
  });

describe("体重記録の置き場", () => {
  describe("HealthKit から取り込んだ体重と体脂肪率があるとき", () => {
    let seed: Seed;
    beforeEach(() => {
      seed = async (factory) => {
        await factory.weightRecords.create({ id: "weight-1" });
        await factory.importedWeightRecords.create({
          weightRecordId: "weight-1",
          healthkitSampleUuid: "weight-sample-1",
        });
        await factory.importedBodyFatPercentages.create({
          weightRecordId: "weight-1",
          bodyFatPercentage: 18.5,
          healthkitSampleUuid: "body-fat-sample-1",
        });
      };
    });

    test("取り込みの情報と体脂肪率を含めて読むこと", async () => {
      const record = await withStore(seed, (store) => store.find("weight-1"));
      expect(record).toMatchObject({
        id: "weight-1",
        imported: {
          healthkitSampleUuid: "weight-sample-1",
          bodyFat: { percentage: 18.5, healthkitSampleUuid: "body-fat-sample-1" },
        },
      });
    });

    test("取り込んだ体重の標本を見つけること", async () => {
      const exists = await withStore(seed, (store) =>
        store.existsImportedSample("weight-sample-1"),
      );
      expect(exists).toBe(true);
    });
  });

  describe("削除の印があるとき", () => {
    let seed: Seed;
    beforeEach(() => {
      seed = async (factory) => {
        const receipt = await factory.syncWriteReceipts.create({ recordId: "weight-1" });
        await factory.weightRecordDeletions.create({ syncWriteReceiptId: receipt.id });
      };
    });

    test("削除した記録の ID で見つけること", async () => {
      expect(await withStore(seed, (store) => store.hasDeletion("weight-1"))).toBe(true);
    });

    test("削除していない記録の ID では見つけないこと", async () => {
      expect(await withStore(seed, (store) => store.hasDeletion("weight-2"))).toBe(false);
    });
  });
});
