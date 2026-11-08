import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId, type RecordId } from "../record-id";
import type { CurrentRecord } from "../sync-ledger/current-record";
import type { RecordChangeTarget } from "../sync-ledger/record-change-target";
import { type WatchedKind, watchCurrentRecords } from "./index";

describe("記録の見張り", () => {
  let values: Map<RecordId, CurrentRecord<unknown>>;
  let kind: WatchedKind<"test_status">;
  let changes: RecordChangeTarget<"test_status">[];
  let watcher: ReturnType<typeof watchCurrentRecords<"test_status">>;
  beforeEach(() => {
    values = new Map();
    kind = {
      name: "test_status",
      readCurrent: (id) => values.get(id) ?? { status: "absent" },
    };
    changes = [];
    watcher = watchCurrentRecords<"test_status">((change) => {
      changes.push(change);
    });
  });

  describe("値が変わった記録と、無いところから消えた記録を、変えた順と逆に見張ったとき", () => {
    let first: RecordId;
    let second: RecordId;
    beforeEach(() => {
      first = generateRecordId();
      second = generateRecordId();
      values.set(first, { status: "value", value: { step: "waiting" } });
      watcher.watch(kind, second);
      watcher.watch(kind, first);
      values.set(first, { status: "value", value: { step: "done" } });
      values.set(second, { status: "deleted" });
      watcher.addChanges();
    });

    test("見張った順に変更を足すこと", () => {
      expect(changes).toEqual([
        { recordType: "test_status", recordId: second },
        { recordType: "test_status", recordId: first },
      ]);
    });
  });

  describe("同じ記録を2回見張ったとき", () => {
    let recordId: RecordId;
    beforeEach(() => {
      recordId = generateRecordId();
      values.set(recordId, { status: "value", value: "waiting" });
      watcher.watch(kind, recordId);
      values.set(recordId, { status: "value", value: "estimating" });
      watcher.watch(kind, recordId);
      watcher.addChanges();
    });

    test("初めに見張ったときの値と比べ、変更を1つ足すこと", () => {
      expect(changes).toEqual([{ recordType: "test_status", recordId }]);
    });
  });

  describe("見張った記録の値が同じ形のまま変わらないとき", () => {
    let recordId: RecordId;
    beforeEach(() => {
      recordId = generateRecordId();
      values.set(recordId, { status: "value", value: { step: "waiting" } });
      watcher.watch(kind, recordId);
      values.set(recordId, { status: "value", value: { step: "waiting" } });
      watcher.addChanges();
    });

    test("変更を足さないこと", () => {
      expect(changes).toEqual([]);
    });
  });

  describe("見張った記録が消えたまま変わらないとき", () => {
    let recordId: RecordId;
    beforeEach(() => {
      recordId = generateRecordId();
      values.set(recordId, { status: "deleted" });
      watcher.watch(kind, recordId);
      values.set(recordId, { status: "deleted" });
      watcher.addChanges();
    });

    test("変更を足さないこと", () => {
      expect(changes).toEqual([]);
    });
  });
});
