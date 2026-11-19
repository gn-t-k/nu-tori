import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../../domain/record-id";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import type { WeightRecordStore } from "../domain/weight-record-store";
import { createWeightRecordStore } from "./create-weight-record-store";

const weight1 = generateRecordId();
const weight2 = generateRecordId();

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
        await factory.weightRecords.create({ id: weight1 });
        await factory.importedWeightRecords.create({
          weightRecordId: weight1,
          healthkitSampleUuid: "weight-sample-1",
        });
        await factory.importedBodyFatPercentages.create({
          weightRecordId: weight1,
          bodyFatPercentage: 18.5,
          healthkitSampleUuid: "body-fat-sample-1",
        });
      };
    });

    test("取り込みの情報と体脂肪率を含めて読むこと", async () => {
      const record = await withStore(seed, (store) => store.find(weight1));
      expect(record).toMatchObject({
        id: weight1,
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
        const receipt = await factory.syncWriteReceipts.create({ recordId: weight1 });
        await factory.weightRecordDeletions.create({ syncWriteReceiptId: receipt.id });
      };
    });

    test("削除した記録の ID で見つけること", async () => {
      expect(await withStore(seed, (store) => store.hasDeletion(weight1))).toBe(true);
    });

    test("削除していない記録の ID では見つけないこと", async () => {
      expect(await withStore(seed, (store) => store.hasDeletion(weight2))).toBe(false);
    });
  });

  describe("体重と時刻を直した記録と、直していない記録があるとき", () => {
    let seed: Seed;
    beforeEach(() => {
      seed = async (factory) => {
        await factory.weightRecords.create({
          id: weight1,
          weightKg: 60.5,
          measuredAt: new Date("2026-01-01T00:00:00Z"),
        });
        await factory.weightRecords.create({
          id: weight2,
          weightKg: 70.0,
          measuredAt: new Date("2026-01-03T00:00:00Z"),
        });
        // 受け取った順は控えの ID や行の順でなく、変更の通し番号で決まる。あとに置く行を、前の通し番号にする
        const corrections = [
          { receiptId: "update-later", sequence: 2, weightKg: 62.0 },
          { receiptId: "update-earlier", sequence: 1, weightKg: 61.0 },
        ];
        for (const { receiptId, sequence, weightKg } of corrections) {
          await factory.syncWriteReceipts.create({
            id: receiptId,
            kind: "update",
            recordId: weight1,
          });
          await factory.recordChanges.create({ sequence, recordId: weight1 });
          await factory.syncWriteRecordChanges.create({
            recordChangeSequence: sequence,
            syncWriteReceiptId: receiptId,
          });
          await factory.weightRecordWeightCorrections.create({
            syncWriteReceiptId: receiptId,
            weightKg,
          });
        }
        await factory.weightRecordMeasuredAtCorrections.create({
          syncWriteReceiptId: "update-earlier",
          measuredAt: new Date("2026-01-05T00:00:00Z"),
          timeZone: "America/Los_Angeles",
        });
      };
    });

    test("ID で読むと、受け取った順でいちばんあとの修正を今の値にし、版を当てた直す控えの数から出すこと", async () => {
      const record = await withStore(seed, (store) => store.find(weight1));
      expect(record).toMatchObject({
        weightKg: 62.0,
        measuredAt: new Date("2026-01-05T00:00:00Z"),
        timeZone: "America/Los_Angeles",
        version: 3,
      });
    });

    test("全件を読むと、ID で読んだのと同じ今の値を、今の時刻の順に返すこと", async () => {
      const { all, found } = await withStore(seed, (store) => ({
        all: store.findAllInMeasuredOrder(),
        found: [store.find(weight2), store.find(weight1)],
      }));
      expect(all).toEqual(
        found.map((record) => ({
          id: record?.id,
          weightKg: record?.weightKg,
          measuredAt: record?.measuredAt,
          timeZone: record?.timeZone,
        })),
      );
    });

    test("時刻の範囲で読むと、直して範囲に入った記録を返すこと", async () => {
      const records = await withStore(seed, (store) =>
        store.findMeasuredBetween(
          new Date("2026-01-04T00:00:00Z"),
          new Date("2026-01-06T00:00:00Z"),
        ),
      );
      expect(records.map(({ id }) => id)).toEqual([weight1]);
    });

    test("時刻の範囲で読むと、作ったときの時刻が範囲に入っても、直して範囲から出た記録は返さないこと", async () => {
      const records = await withStore(seed, (store) =>
        store.findMeasuredBetween(
          new Date("2026-01-01T00:00:00Z"),
          new Date("2026-01-04T00:00:00Z"),
        ),
      );
      expect(records.map(({ id }) => id)).toEqual([weight2]);
    });

    test("直した記録だけを、直したと見ること", async () => {
      const corrected = await withStore(seed, (store) => [
        store.hasCorrection(weight1),
        store.hasCorrection(weight2),
      ]);
      expect(corrected).toEqual([true, false]);
    });
  });
});
