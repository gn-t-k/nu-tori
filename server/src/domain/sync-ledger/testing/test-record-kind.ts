import type { CurrentRecord } from "../current-record";
import type { RecordKind } from "../record-kind";

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

// 帳簿のテスト用の種類。100 を超える値は受け付けない
export const createTestRecordKind = (
  store: TestRecordStore,
): RecordKind<"test_record", TestRecordWrite, number> => ({
  name: "test_record",
  writes: {
    isWrite: (write): write is TestRecordWrite =>
      write.type === "create_test_record" ||
      write.type === "update_test_record" ||
      write.type === "delete_test_record",
    decide: (write) => {
      if (write.type === "delete_test_record") {
        return {
          writeKind: "source_deleted",
          recordId: write.recordId,
          outcome: { result: "applied" },
          changedRecordId: write.recordId,
          commit: (receiptId) => {
            store.remove(write.recordId);
            store.insertDeletion(receiptId.value, write.recordId);
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
          commit: () => undefined,
        };
      }
      if (store.hasDeletion(write.recordId)) {
        return {
          writeKind,
          recordId: write.recordId,
          outcome: { result: "ignored_tombstone" },
          changedRecordId: write.recordId,
          commit: () => undefined,
        };
      }
      return {
        writeKind,
        recordId: write.recordId,
        outcome: { result: "applied" },
        changedRecordId: write.recordId,
        commit: () =>
          writeKind === "create"
            ? store.insert(write.recordId, write.value)
            : store.update(write.recordId, write.value),
      };
    },
  },
  readCurrent: (recordId): CurrentRecord<number> => {
    const value = store.find(recordId);
    if (value !== undefined) {
      return { status: "value", value };
    }
    return store.hasDeletion(recordId) ? { status: "deleted" } : { status: "absent" };
  },
});
