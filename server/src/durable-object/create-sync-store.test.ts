import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import type { SyncStore } from "../domain/sync-store";
import { createSyncStore } from "./create-sync-store";
import { durableObjectTables } from "./durable-object-tables";
import { durableObjectFactory } from "./testing/durable-object-factory";

type Seed = (factory: ReturnType<typeof durableObjectFactory>) => Promise<void>;

// 行は factory で作り、置き場の読み取りを実物の Durable Object の中で確かめる
const withStore = <T>(seed: Seed, read: (store: SyncStore) => T): Promise<T> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), async (_, state) => {
    await seed(durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })));
    return read(createSyncStore(state.storage));
  });

describe("同期の置き場", () => {
  describe("体重記録を読むとき", () => {
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
        const record = await withStore(seed, (store) => store.findWeightRecord("weight-1"));
        expect(record).toMatchObject({
          id: "weight-1",
          measuredAt: new Date("2026-01-01T00:00:00Z"),
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

    describe("手で記録した体重のとき", () => {
      let seed: Seed;
      beforeEach(() => {
        seed = async (factory) => {
          await factory.weightRecords.create({ id: "weight-1" });
        };
      });

      test("取り込みの情報を持たずに読むこと", async () => {
        const record = await withStore(seed, (store) => store.findWeightRecord("weight-1"));
        expect(record?.imported).toBeUndefined();
      });
    });
  });

  describe("書き込みの結果を読むとき", () => {
    describe("拒んだ書き込みのとき", () => {
      let seed: Seed;
      beforeEach(() => {
        seed = async (factory) => {
          const receipt = await factory.syncWriteReceipts.create({
            id: "write-1",
            result: "rejected",
          });
          await factory.syncWriteRejections.create({
            syncWriteReceiptId: receipt.id,
            reason: "version_too_low",
          });
        };
      });

      test("理由を含めて読むこと", async () => {
        const outcome = await withStore(seed, (store) => store.findWriteOutcome("write-1"));
        expect(outcome).toEqual({ result: "rejected", reason: "version_too_low" });
      });
    });

    describe("受け付けた書き込みのとき", () => {
      let seed: Seed;
      beforeEach(() => {
        seed = async (factory) => {
          await factory.syncWriteReceipts.create({ id: "write-1", result: "kept_corrected" });
        };
      });

      test("結果だけを読むこと", async () => {
        const outcome = await withStore(seed, (store) => store.findWriteOutcome("write-1"));
        expect(outcome).toEqual({ result: "kept_corrected" });
      });
    });
  });

  describe("体重記録の削除の控えを読むとき", () => {
    let seed: Seed;
    beforeEach(() => {
      seed = async (factory) => {
        const receipt = await factory.syncWriteReceipts.create({ recordId: "weight-1" });
        await factory.weightRecordDeletions.create({ syncWriteReceiptId: receipt.id });
      };
    });

    test("削除した記録の ID で見つけること", async () => {
      const exists = await withStore(seed, (store) => store.existsWeightRecordDeletion("weight-1"));
      expect(exists).toBe(true);
    });

    test("削除していない記録の ID では見つけないこと", async () => {
      const exists = await withStore(seed, (store) => store.existsWeightRecordDeletion("weight-2"));
      expect(exists).toBe(false);
    });
  });

  describe("記録ごとの最後の変更を読むとき", () => {
    let seed: Seed;
    beforeEach(() => {
      seed = async (factory) => {
        await factory.recordChanges.create([
          { sequence: 1, recordType: "weight_record", recordId: "weight-1" },
          { sequence: 2, recordType: "account_settings", recordId: "settings-1" },
          { sequence: 3, recordType: "weight_record", recordId: "weight-1" },
        ]);
      };
    });

    test("記録ごとに最後の変更を、順番に読むこと", async () => {
      const changes = await withStore(seed, (store) => store.findLatestChangePerRecord(0, 10));
      expect(changes).toEqual([
        { sequence: 2, recordType: "account_settings", recordId: "settings-1" },
        { sequence: 3, recordType: "weight_record", recordId: "weight-1" },
      ]);
    });

    test("指定した番号より後の変更だけを、件数の上限まで読むこと", async () => {
      const changes = await withStore(seed, (store) => store.findLatestChangePerRecord(1, 1));
      expect(changes).toEqual([
        { sequence: 2, recordType: "account_settings", recordId: "settings-1" },
      ]);
    });
  });
});
