import { beforeEach, describe, expect, test } from "vitest";
import type { SyncClientState } from "../sync-client-state";
import { createSyncLedger, type WriteReceiptId } from "./sync-ledger";
import { createMemoryLedgerStore } from "./testing/create-memory-ledger-store";
import { createMemoryTestRecordStore } from "./testing/create-memory-test-record-store";
import { createTestRecordKind, type TestRecordWrite } from "./testing/test-record-kind";

const acceptReceiptId = (_receiptId: WriteReceiptId) => undefined;

type OtherWrite = { id: string; type: "other_write" };
type TestLedger = ReturnType<
  typeof createSyncLedger<
    "test_record" | "other",
    "test_record",
    TestRecordWrite | OtherWrite,
    number
  >
>;

describe("同期の帳簿", () => {
  let operations: string[];
  let ledgerStore: ReturnType<typeof createMemoryLedgerStore<"test_record" | "other">>;
  let ledger: TestLedger;
  let clientState: SyncClientState;
  let receivedAt: Date;
  let pullRequest: (afterSequence: number) => Parameters<TestLedger["pull"]>[0];
  let pushRequest: (writes: (TestRecordWrite | OtherWrite)[]) => Parameters<TestLedger["push"]>[0];
  let create: (id: string, recordId: string, value?: number) => TestRecordWrite;

  beforeEach(() => {
    operations = [];
    ledgerStore = createMemoryLedgerStore(operations);
    ledger = createSyncLedger<
      "test_record" | "other",
      "test_record",
      TestRecordWrite | OtherWrite,
      number
    >(ledgerStore, [createTestRecordKind(createMemoryTestRecordStore(operations))]);
    clientState = {
      deviceId: "device-1",
      timeZone: "Asia/Tokyo",
      appVersion: "1.0",
      osVersion: "26.0",
      pendingWriteCount: 0,
      oldestPendingWriteAgeSeconds: undefined,
      pendingPhotoCount: 0,
    };
    receivedAt = new Date("2026-01-01T00:00:00Z");
    pullRequest = (afterSequence) => ({ clientState, afterSequence, receivedAt });
    pushRequest = (writes) => ({ clientState, writes, isFinalBatch: true, receivedAt });
    create = (id, recordId, value = 1) => ({ id, type: "create_test_record", recordId, value });
  });

  describe("書き込みを送るとき", () => {
    describe("受け付ける書き込みを1件送ったとき", () => {
      beforeEach(() => {
        ledger.push(pushRequest([create("write-1", "record-1")]));
      });

      test("要求の控え、書き込みの控え、種類の行、変更の並びの順に書くこと", () => {
        expect(operations).toEqual(["request_log", "receipt", "record", "change"]);
      });
    });

    describe("削除の書き込みを送ったとき", () => {
      beforeEach(() => {
        ledger.push(
          pushRequest([{ id: "write-1", type: "delete_test_record", recordId: "record-1" }]),
        );
      });

      test("削除の印は、控えのあとに書くこと", () => {
        expect(operations).toEqual(["request_log", "receipt", "record", "deletion", "change"]);
      });
    });

    describe("同じ書き込みの ID が再び届いたとき", () => {
      let first: ReturnType<TestLedger["push"]>;
      let second: ReturnType<TestLedger["push"]>;

      beforeEach(() => {
        first = ledger.push(pushRequest([create("write-1", "record-1")]));
        operations.length = 0;
        second = ledger.push(pushRequest([create("write-1", "record-1", 500)]));
      });

      test("最初の結果を返すこと", () => {
        expect(second.results).toEqual(first.results);
      });

      test("要求の控えのほかは何も書き足さないこと", () => {
        expect(operations).toEqual(["request_log"]);
      });
    });

    describe("受け付けない値の書き込みを送ったとき", () => {
      let pushed: ReturnType<TestLedger["push"]>;

      beforeEach(() => {
        pushed = ledger.push(pushRequest([create("write-1", "record-1", 500)]));
      });

      test("受け付けなかった1件として返すこと", () => {
        expect(pushed.rejectedWrites).toEqual([
          { writeKind: "create", recordType: "test_record", reason: "out_of_range" },
        ]);
      });

      test("変更の並びに載せないこと", () => {
        expect(operations).toEqual(["request_log", "receipt"]);
      });
    });

    describe("登録簿にない書き込みが混ざるとき", () => {
      let pushWithUnregistered: () => unknown;

      beforeEach(() => {
        pushWithUnregistered = () =>
          ledger.push(
            pushRequest([create("write-1", "record-1"), { id: "write-2", type: "other_write" }]),
          );
      });

      test("不具合として投げること", () => {
        expect(pushWithUnregistered).toThrow("登録簿に無い書き込み: other_write");
      });
    });
  });

  describe("変更を取りに行くとき", () => {
    describe("同じ記録に書き込みが重なっているとき", () => {
      let pulled: ReturnType<TestLedger["pull"]>;

      beforeEach(() => {
        ledger.push(
          pushRequest([
            create("write-1", "record-1", 1),
            { id: "write-2", type: "update_test_record", recordId: "record-1", value: 2 },
            create("write-3", "record-2"),
            { id: "write-4", type: "delete_test_record", recordId: "record-2" },
          ]),
        );
        pulled = ledger.pull(pullRequest(0));
      });

      test("記録ごとに最新の1件にまとめ、値と削除の印を返すこと", () => {
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
    });

    describe("500 件を超える記録があるとき", () => {
      let firstPage: ReturnType<TestLedger["pull"]>;
      let secondPage: ReturnType<TestLedger["pull"]>;

      beforeEach(() => {
        ledger.push(
          pushRequest(
            Array.from({ length: 501 }, (_, index) => create(`write-${index}`, `record-${index}`)),
          ),
        );
        firstPage = ledger.pull(pullRequest(0));
        secondPage = ledger.pull(pullRequest(firstPage.lastSequence ?? 0));
      });

      test("500 件で区切り、続きがあると知らせること", () => {
        expect([
          firstPage.changes.length,
          firstPage.hasMore,
          secondPage.changes.length,
          secondPage.hasMore,
        ]).toEqual([500, true, 1, false]);
      });
    });

    describe("登録簿にない種類の変更があるとき", () => {
      let pullWithUnregistered: () => unknown;

      beforeEach(() => {
        ledgerStore.insertRecordChange({ recordType: "other", recordId: "x", writeId: "w" });
        pullWithUnregistered = () => ledger.pull(pullRequest(0));
      });

      test("不具合として投げること", () => {
        expect(pullWithUnregistered).toThrow("登録簿に無い種類の変更: other");
      });
    });
  });

  describe("型の検査（tsc が確かめる）", () => {
    // 確かめるのは tsc で、実行時の assertion は無い
    // oxlint-disable-next-line vitest/expect-expect
    test("控えの ID は、文字列から作れないこと", () => {
      // @ts-expect-error 文字列から控えの ID は作れない（作れるとコンパイルが通ってしまう）
      acceptReceiptId("write-1");
    });
  });
});
