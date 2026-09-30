export type TestRecordStore = {
  find: (id: string) => number | undefined;
  hasDeletion: (recordId: string) => boolean;
  insert: (id: string, value: number) => void;
  update: (id: string, value: number) => void;
  remove: (id: string) => void;
  insertDeletion: (receiptId: string, recordId: string) => void;
};
