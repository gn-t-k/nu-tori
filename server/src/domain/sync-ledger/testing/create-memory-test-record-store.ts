import type { TestRecordStore } from "./test-record-store";

export const createMemoryTestRecordStore = (operations: string[]): TestRecordStore => {
  const values = new Map<string, number>();
  const deletedRecordIds = new Set<string>();
  return {
    find: (id) => values.get(id),
    hasDeletion: (recordId) => deletedRecordIds.has(recordId),
    insert: (id, value) => {
      operations.push("record");
      values.set(id, value);
    },
    update: (id, value) => {
      operations.push("record");
      values.set(id, value);
    },
    remove: (id) => {
      operations.push("record");
      values.delete(id);
    },
    insertDeletion: (_receiptId, recordId) => {
      operations.push("deletion");
      deletedRecordIds.add(recordId);
    },
  };
};
