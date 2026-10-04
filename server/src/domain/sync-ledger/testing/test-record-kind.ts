import type { CurrentRecord } from "../current-record";
import type { RecordKind } from "../record-kind";
import type { TestChildStore } from "./test-child-kind";

export type TestRecordStore = {
  find: (id: string) => number | undefined;
  hasDeletion: (recordId: string) => boolean;
  insert: (id: string, value: number) => void;
  update: (id: string, value: number) => void;
  remove: (id: string) => void;
  insertDeletion: (receiptId: string, recordId: string) => void;
};

export type TestRecordWrite =
  | { id: string; type: "create_test_record"; recordId: string; value: number }
  | { id: string; type: "update_test_record"; recordId: string; value: number }
  | { id: string; type: "delete_test_record"; recordId: string };

// 帳簿のテスト用の種類。100 を超える値は受け付けない。消すと子も消す
export const createTestRecordKind = (
  store: TestRecordStore,
  childStore: TestChildStore,
): RecordKind<"test_record", TestRecordWrite, number, "test_child"> => ({
  name: "test_record",
  writes: {
    isWrite: (write): write is TestRecordWrite =>
      write.type === "create_test_record" ||
      write.type === "update_test_record" ||
      write.type === "delete_test_record",
    decide: (write) => {
      if (write.type === "delete_test_record") {
        const childIds = childStore.findIdsOfParent(write.recordId);
        return {
          writeKind: "source_deleted",
          recordId: write.recordId,
          outcome: { result: "applied" },
          changedRecordId: write.recordId,
          addedChanges: childIds.map((childId) => ({
            recordType: "test_child",
            recordId: childId,
          })),
          usageEvents: [],
          commit: (receiptId) => {
            store.remove(write.recordId);
            store.insertDeletion(receiptId.value, write.recordId);
            for (const childId of childIds) {
              childStore.removeWithDeletion(childId);
            }
          },
        };
      }
      const writeKind = write.type === "create_test_record" ? "create" : "update";
      if (write.value > 100) {
        return {
          writeKind,
          recordId: write.recordId,
          outcome: { result: "rejected", reason: "out_of_range" },
          changedRecordId: undefined,
          addedChanges: [],
          usageEvents: [],
          commit: () => undefined,
        };
      }
      if (store.hasDeletion(write.recordId)) {
        return {
          writeKind,
          recordId: write.recordId,
          outcome: { result: "ignored_tombstone" },
          changedRecordId: write.recordId,
          addedChanges: [],
          usageEvents: [],
          commit: () => undefined,
        };
      }
      return {
        writeKind,
        recordId: write.recordId,
        outcome: { result: "applied" },
        changedRecordId: write.recordId,
        addedChanges: [],
        usageEvents: [],
        commit: () =>
          writeKind === "create"
            ? store.insert(write.recordId, write.value)
            : store.update(write.recordId, write.value),
      };
    },
  },
  follows: undefined,
  whenGone: "deletion_mark",
  readCurrent: (recordId): CurrentRecord<number> => {
    const value = store.find(recordId);
    if (value !== undefined) {
      return { status: "value", value };
    }
    return store.hasDeletion(recordId) ? { status: "deleted" } : { status: "absent" };
  },
});
