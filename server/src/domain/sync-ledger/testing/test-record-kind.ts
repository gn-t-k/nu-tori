import type { RecordId } from "../../record-id";
import type { CurrentRecord } from "../current-record";
import type { RecordKind } from "../record-kind";
import { rejectWrite } from "../reject-write";
import type { TestChildStore } from "./test-child-kind";

export type TestRecordStore = {
  find: (id: RecordId) => number | undefined;
  hasDeletion: (recordId: RecordId) => boolean;
  insert: (id: RecordId, value: number) => void;
  update: (id: RecordId, value: number) => void;
  remove: (id: RecordId) => void;
  insertDeletion: (receiptId: string, recordId: RecordId) => void;
};

export type TestRecordWrite =
  | { id: string; type: "create_test_record"; recordId: RecordId; value: number }
  | { id: string; type: "update_test_record"; recordId: RecordId; value: number }
  | { id: string; type: "delete_test_record"; recordId: RecordId }
  | {
      id: string;
      type: "create_test_record_with_children";
      recordId: RecordId;
      // 決定で宣言する子と、commit の中で足す子。両方にある子は、変更が重なる
      declaredChildIds: RecordId[];
      addedInCommitChildIds: RecordId[];
    };

// 帳簿のテスト用の種類。100 を超える値は受け付けない。今と同じ値に直す書き込みは何も書かない。消すと子も消す
export const createTestRecordKind = (
  store: TestRecordStore,
  childStore: TestChildStore,
): RecordKind<"test_record", TestRecordWrite, number, "test_child"> => ({
  name: "test_record",
  writes: {
    isWrite: (write): write is TestRecordWrite =>
      write.type === "create_test_record" ||
      write.type === "update_test_record" ||
      write.type === "delete_test_record" ||
      write.type === "create_test_record_with_children",
    decide: (write) => {
      if (write.type === "delete_test_record") {
        const childIds = childStore.findIdsOfParent(write.recordId);
        return {
          result: "applied",
          writeKind: "source_deleted",
          recordId: write.recordId,
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
      if (write.type === "create_test_record_with_children") {
        return {
          result: "applied",
          writeKind: "create",
          recordId: write.recordId,
          addedChanges: write.declaredChildIds.map((childId) => ({
            recordType: "test_child",
            recordId: childId,
          })),
          usageEvents: [],
          commit: (_receiptId, addChange) => {
            store.insert(write.recordId, 1);
            for (const childId of write.addedInCommitChildIds) {
              childStore.insert({ id: childId, parentId: write.recordId, value: 1 });
              addChange({ recordType: "test_child", recordId: childId });
            }
          },
        };
      }
      const writeKind = write.type === "create_test_record" ? "create" : "update";
      if (write.value > 100) {
        return rejectWrite(writeKind, write.recordId, "out_of_range");
      }
      if (store.hasDeletion(write.recordId)) {
        return { result: "ignored_tombstone", writeKind, recordId: write.recordId };
      }
      if (writeKind === "update" && store.find(write.recordId) === write.value) {
        return { result: "unchanged", writeKind, recordId: write.recordId };
      }
      return {
        result: "applied",
        writeKind,
        recordId: write.recordId,
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
