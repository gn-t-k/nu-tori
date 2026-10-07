import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../domain/record-id";
import type { RecordType } from "../domain/record-type";
import type { LedgerStore } from "../domain/sync-ledger/ledger-store";
import { createLedgerStore } from "./create-ledger-store";
import { durableObjectTables } from "./durable-object-tables";
import { durableObjectFactory } from "./testing/durable-object-factory";

const weight1 = generateRecordId();
const settings1 = generateRecordId();

type Seed = (factory: ReturnType<typeof durableObjectFactory>) => Promise<void>;

// 行は factory で作り、置き場の読み取りを実物の Durable Object の中で確かめる
const withStore = <T>(seed: Seed, read: (store: LedgerStore<RecordType>) => T): Promise<T> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), async (_, state) => {
    await seed(durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })));
    return read(createLedgerStore(state.storage));
  });

describe("帳簿の置き場", () => {
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
        const receipt = await withStore(seed, (store) => store.findWriteReceipt("write-1"));
        expect(receipt?.outcome).toEqual({ result: "rejected", reason: "version_too_low" });
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
        const receipt = await withStore(seed, (store) => store.findWriteReceipt("write-1"));
        expect(receipt?.outcome).toEqual({ result: "kept_corrected" });
      });
    });
  });

  describe("書き込みの控えと結ばない変更を書くとき", () => {
    let rows: { recordChanges: unknown[]; links: unknown[] };
    beforeEach(async () => {
      rows = await runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), (_, state) => {
        createLedgerStore(state.storage).insertRecordChange({
          recordType: "weight_record",
          recordId: weight1,
          writeId: undefined,
        });
        return {
          recordChanges: state.storage.sql
            .exec("SELECT sequence, record_type, record_id FROM record_changes")
            .toArray(),
          links: state.storage.sql.exec("SELECT * FROM sync_write_record_changes").toArray(),
        };
      });
    });

    test("変更の並びに書き、控えとのつなぎを書かないこと", () => {
      expect(rows).toEqual({
        recordChanges: [{ sequence: 1, record_type: "weight_record", record_id: weight1 }],
        links: [],
      });
    });
  });

  describe("記録ごとの最後の変更を読むとき", () => {
    let seed: Seed;
    beforeEach(() => {
      seed = async (factory) => {
        await factory.recordChanges.create([
          { sequence: 1, recordType: "weight_record", recordId: weight1 },
          { sequence: 2, recordType: "account_settings", recordId: settings1 },
          { sequence: 3, recordType: "weight_record", recordId: weight1 },
        ]);
      };
    });

    test("記録ごとに最後の変更を、順番に読むこと", async () => {
      const changes = await withStore(seed, (store) => store.findLatestChangePerRecord(0, 10));
      expect(changes).toEqual([
        { sequence: 2, recordType: "account_settings", recordId: settings1 },
        { sequence: 3, recordType: "weight_record", recordId: weight1 },
      ]);
    });

    test("指定した番号より後の変更だけを、件数の上限まで読むこと", async () => {
      const changes = await withStore(seed, (store) => store.findLatestChangePerRecord(1, 1));
      expect(changes).toEqual([
        { sequence: 2, recordType: "account_settings", recordId: settings1 },
      ]);
    });
  });
});
