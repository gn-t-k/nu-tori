import { beforeEach, describe, expect, test } from "vitest";
import { createMemoryLedgerStore } from "./testing/create-memory-ledger-store";
import { createMemoryTestRecordStore } from "./testing/create-memory-test-record-store";
import { createTestRecordKind, type TestRecordWrite } from "./testing/test-record-kind";
import { createSyncLedger, type WriteReceiptId } from "./sync-ledger";
import type { SyncClientState } from "../sync-client-state";

const clientState: SyncClientState = {
  deviceId: "device-1",
  timeZone: "Asia/Tokyo",
  appVersion: "1.0",
  osVersion: "26.0",
  pendingWriteCount: 0,
  oldestPendingWriteAgeSeconds: undefined,
  pendingPhotoCount: 0,
};
const receivedAt = new Date("2026-01-01T00:00:00Z");

const pullRequest = (afterSequence: number) => ({ clientState, afterSequence, receivedAt });

type OtherWrite = { id: string; type: "other_write" };
const pushRequest = (writes: (TestRecordWrite | OtherWrite)[]) => ({
  clientState,
  writes,
  isFinalBatch: true,
  receivedAt,
});
const create = (id: string, recordId: string, value = 1): TestRecordWrite => ({
  id,
  type: "create_test_record",
  recordId,
  value,
});

describe("同期の帳簿", () => {
  let operations: string[];
  let ledgerStore: ReturnType<typeof createMemoryLedgerStore<"test_record" | "other">>;
  let ledger: ReturnType<
    typeof createSyncLedger<
      "test_record" | "other",
      "test_record",
      TestRecordWrite | OtherWrite,
      number
    >
  >;
  beforeEach(() => {
    operations = [];
    ledgerStore = createMemoryLedgerStore(operations);
    ledger = createSyncLedger<
      "test_record" | "other",
      "test_record",
      TestRecordWrite | OtherWrite,
      number
    >(ledgerStore, [createTestRecordKind(createMemoryTestRecordStore(operations))]);
  });

  describe("書き込みを送るとき", () => {
    test("要求の控え、書き込みの控え、種類の行、変更の並びの順に書くこと", () => {
      ledger.push(pushRequest([create("write-1", "record-1")]));
      expect(operations).toEqual(["request_log", "receipt", "record", "change"]);
    });

    test("削除の印は、控えのあとに書くこと", () => {
      ledger.push(
        pushRequest([{ id: "write-1", type: "delete_test_record", recordId: "record-1" }]),
      );
      expect(operations).toEqual(["request_log", "receipt", "record", "deletion", "change"]);
    });

    test("同じ書き込みの ID が再び届いたら、最初の結果を返し、何も書き足さないこと", () => {
      const first = ledger.push(pushRequest([create("write-1", "record-1")]));
      operations.length = 0;
      const second = ledger.push(pushRequest([create("write-1", "record-1", 500)]));
      expect(second.results).toEqual(first.results);
      expect(operations).toEqual(["request_log"]);
    });

    test("受け付けなかった書き込みは、変更の並びに載せず、受け付けなかった1件として返すこと", () => {
      const pushed = ledger.push(pushRequest([create("write-1", "record-1", 500)]));
      expect(pushed.rejectedWrites).toEqual([
        { writeKind: "create", recordType: "test_record", reason: "out_of_range" },
      ]);
      expect(operations).toEqual(["request_log", "receipt"]);
    });
  });

  describe("登録簿にない書き込みが混ざるとき", () => {
    test("不具合として投げること", () => {
      expect(() =>
        ledger.push(
          pushRequest([create("write-1", "record-1"), { id: "write-2", type: "other_write" }]),
        ),
      ).toThrow("登録簿に無い書き込み: other_write");
    });
  });

  describe("変更を取りに行くとき", () => {
    test("記録ごとに最新の1件にまとめ、値と削除の印を返すこと", () => {
      ledger.push(
        pushRequest([
          create("write-1", "record-1", 1),
          { id: "write-2", type: "update_test_record", recordId: "record-1", value: 2 },
          create("write-3", "record-2"),
          { id: "write-4", type: "delete_test_record", recordId: "record-2" },
        ]),
      );
      const pulled = ledger.pull(pullRequest(0));
      expect(pulled.changes).toEqual([
        {
          sequence: 2,
          recordType: "test_record",
          recordId: "record-1",
          current: { status: "value", value: 2 },
        },
        {
          sequence: 4,
          recordType: "test_record",
          recordId: "record-2",
          current: { status: "deleted" },
        },
      ]);
    });

    test("500 件で区切り、続きがあると知らせること", () => {
      const writes = Array.from({ length: 501 }, (_, index) =>
        create(`write-${index}`, `record-${index}`),
      );
      ledger.push(pushRequest(writes));
      const firstPage = ledger.pull(pullRequest(0));
      const secondPage = ledger.pull(pullRequest(firstPage.lastSequence ?? 0));
      expect([
        firstPage.changes.length,
        firstPage.hasMore,
        secondPage.changes.length,
        secondPage.hasMore,
      ]).toEqual([500, true, 1, false]);
    });

    test("登録簿にない種類の変更は、不具合として投げること", () => {
      ledgerStore.insertRecordChange({ recordType: "other", recordId: "x", writeId: "w" });
      expect(() => ledger.pull(pullRequest(0))).toThrow("登録簿に無い種類の変更: other");
    });
  });

  describe("控えの ID の型", () => {
    test("帳簿以外は作れないこと", () => {
      // @ts-expect-error 文字列から控えの ID は作れない（作れるとコンパイルが通ってしまう）
      const forged: WriteReceiptId = "write-1";
      expect(forged).toBe("write-1");
    });
  });
});
