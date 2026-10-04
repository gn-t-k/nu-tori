import { beforeEach, describe, expect, test } from "vitest";
import type { SyncClientState } from "../sync-client-state";
import { createSyncLedger } from "./sync-ledger";
import { createMemoryLedgerStore } from "./testing/create-memory-ledger-store";
import { createMemoryTestChildStore } from "./testing/create-memory-test-child-store";
import { createMemoryTestRecordStore } from "./testing/create-memory-test-record-store";
import { createTestChildKind, type TestChildStore } from "./testing/test-child-kind";
import { createTestFollowerKind } from "./testing/test-follower-kind";
import { testFollowerRecordId } from "./testing/test-follower-record-id";
import { createTestRecordKind, type TestRecordWrite } from "./testing/test-record-kind";

type OtherWrite = { id: string; type: "other_write" };
type TestLedger = ReturnType<
  typeof createSyncLedger<
    "test_record" | "test_child" | "test_follower" | "other",
    "test_record" | "test_child" | "test_follower",
    TestRecordWrite | OtherWrite,
    number
  >
>;

describe("同期の帳簿", () => {
  let operations: string[];
  let ledgerStore: ReturnType<
    typeof createMemoryLedgerStore<"test_record" | "test_child" | "test_follower" | "other">
  >;
  let childStore: TestChildStore;
  let ledger: TestLedger;
  let clientState: SyncClientState;
  let receivedAt: Date;
  let pullRequest: (afterSequence: number) => Parameters<TestLedger["pull"]>[0];
  let pushRequest: (writes: (TestRecordWrite | OtherWrite)[]) => Parameters<TestLedger["push"]>[0];
  let create: (id: string, recordId: string, value?: number) => TestRecordWrite;

  beforeEach(() => {
    operations = [];
    ledgerStore = createMemoryLedgerStore(operations);
    childStore = createMemoryTestChildStore(operations);
    ledger = createSyncLedger<
      "test_record" | "test_child" | "test_follower" | "other",
      "test_record" | "test_child" | "test_follower",
      TestRecordWrite | OtherWrite,
      number
    >(ledgerStore, [
      createTestRecordKind(createMemoryTestRecordStore(operations), childStore),
      createTestChildKind(childStore),
    ]);
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

    describe("子のある記録を消す書き込みを送ったとき", () => {
      beforeEach(() => {
        childStore.insert({ id: "child-1", parentId: "record-1", value: 1 });
        operations.length = 0;
        ledger.push(
          pushRequest([{ id: "write-1", type: "delete_test_record", recordId: "record-1" }]),
        );
      });

      test("子の変更は、書き込みの記録の変更のあとに、控えと結ばずに書くこと", () => {
        expect(operations).toEqual([
          "request_log",
          "receipt",
          "record",
          "deletion",
          "child",
          "change",
          "added_change",
        ]);
      });
    });

    describe("同じ書き込みの ID が再び届いたとき", () => {
      beforeEach(() => {
        ledger.push(pushRequest([create("write-1", "record-1")]));
        operations.length = 0;
        ledger.push(pushRequest([create("write-1", "record-1", 500)]));
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

  describe("ほかの種類の記録から計算する種類があるとき", () => {
    beforeEach(() => {
      ledger = createSyncLedger<
        "test_record" | "test_child" | "test_follower" | "other",
        "test_record" | "test_child" | "test_follower",
        TestRecordWrite | OtherWrite,
        number
      >(ledgerStore, [
        createTestRecordKind(createMemoryTestRecordStore(operations), childStore),
        createTestChildKind(childStore),
        createTestFollowerKind(operations),
      ]);
    });

    describe("元の種類の書き込みを当てたとき", () => {
      let pulled: ReturnType<TestLedger["pull"]>;

      beforeEach(() => {
        ledger.push(pushRequest([create("write-1", "record-1")]));
        pulled = ledger.pull(pullRequest(0));
      });

      test("元の書き込みの行と変更を書いたあとに、計算する種類を呼ぶこと", () => {
        expect(operations).toEqual([
          "request_log",
          "receipt",
          "record",
          "change",
          "follower",
          "added_change",
          "request_log",
        ]);
      });

      test("元の書き込みの変更のあとに、計算する種類の変更を返すこと", () => {
        expect(pulled.changes).toEqual([
          {
            sequence: 1,
            recordType: "test_record",
            recordId: "record-1",
            current: { status: "value", value: 1 },
          },
          {
            sequence: 2,
            recordType: "test_follower",
            recordId: testFollowerRecordId,
            current: { status: "value", value: 1 },
          },
        ]);
      });
    });

    describe("元の種類の書き込みを受け付けなかったとき", () => {
      beforeEach(() => {
        ledger.push(pushRequest([create("write-1", "record-1", 500)]));
      });

      test("計算する種類を呼ばないこと", () => {
        expect(operations).toEqual(["request_log", "receipt"]);
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

    describe("書き込みがほかの種類の記録の変更を足したとき", () => {
      let pulled: ReturnType<TestLedger["pull"]>;

      beforeEach(() => {
        childStore.insert({ id: "child-1", parentId: "record-1", value: 1 });
        childStore.insert({ id: "child-2", parentId: "record-1", value: 2 });
        ledger.push(
          pushRequest([{ id: "write-1", type: "delete_test_record", recordId: "record-1" }]),
        );
        pulled = ledger.pull(pullRequest(0));
      });

      test("書き込みの記録のあとに、足した変更を通し番号の順で返すこと", () => {
        expect(pulled.changes).toEqual([
          {
            sequence: 1,
            recordType: "test_record",
            recordId: "record-1",
            current: { status: "deleted" },
          },
          {
            sequence: 2,
            recordType: "test_child",
            recordId: "child-1",
            current: { status: "deleted" },
          },
          {
            sequence: 3,
            recordType: "test_child",
            recordId: "child-2",
            current: { status: "deleted" },
          },
        ]);
      });
    });

    describe("書き込みの外から変更を足したとき", () => {
      let pulled: ReturnType<TestLedger["pull"]>;

      beforeEach(() => {
        ledger.changeOutsideWrites((addChange) => {
          childStore.insert({ id: "child-2", parentId: "record-1", value: 2 });
          addChange({ recordType: "test_child", recordId: "child-2" });
          childStore.insert({ id: "child-1", parentId: "record-1", value: 1 });
          addChange({ recordType: "test_child", recordId: "child-1" });
        });
        pulled = ledger.pull(pullRequest(0));
      });

      test("足した順の通し番号で返すこと", () => {
        expect(pulled.changes).toEqual([
          {
            sequence: 1,
            recordType: "test_child",
            recordId: "child-2",
            current: { status: "value", value: 2 },
          },
          {
            sequence: 2,
            recordType: "test_child",
            recordId: "child-1",
            current: { status: "value", value: 1 },
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
        const { lastSequence } = firstPage;
        if (lastSequence === undefined) {
          throw new Error("1ページ目に最後の通し番号が無い");
        }
        secondPage = ledger.pull(pullRequest(lastSequence));
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

    describe("変更の並びが指す記録も削除の印も無いとき", () => {
      let pullWithoutRecord: () => unknown;

      beforeEach(() => {
        ledger.changeOutsideWrites((addChange) => {
          addChange({ recordType: "test_child", recordId: "child-1" });
        });
        pullWithoutRecord = () => ledger.pull(pullRequest(0));
      });

      test("不具合として投げること", () => {
        expect(pullWithoutRecord).toThrow(
          "変更の並びが指す記録も削除の印も無い: test_child child-1",
        );
      });
    });

    describe("記録が無くなったことを届ける種類で、記録も削除の印も無いとき", () => {
      let pulled: ReturnType<TestLedger["pull"]>;

      beforeEach(() => {
        const ledgerDeliveringAbsence = createSyncLedger<
          "test_record" | "test_child" | "test_follower" | "other",
          "test_record" | "test_child" | "test_follower",
          TestRecordWrite | OtherWrite,
          number
        >(ledgerStore, [
          createTestRecordKind(createMemoryTestRecordStore(operations), childStore),
          { ...createTestChildKind(childStore), deliversAbsence: true },
        ]);
        ledgerDeliveringAbsence.changeOutsideWrites((addChange) => {
          addChange({ recordType: "test_child", recordId: "child-1" });
        });
        pulled = ledgerDeliveringAbsence.pull(pullRequest(0));
      });

      test("記録が無いことを変更として返すこと", () => {
        expect(pulled.changes).toEqual([
          {
            sequence: 1,
            recordType: "test_child",
            recordId: "child-1",
            current: { status: "absent" },
          },
        ]);
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
});
