import type { CurrentRecord } from "../current-record";
import type { RecordKind } from "../record-kind";

export type TestChildStore = {
  find: (id: string) => number | undefined;
  findIdsOfParent: (parentId: string) => string[];
  hasDeletion: (id: string) => boolean;
  insert: (child: { id: string; parentId: string; value: number }) => void;
  removeWithDeletion: (id: string) => void;
};

// 帳簿のテスト用の、サーバーだけが書く種類。テスト用の記録を親に持つ
export const createTestChildKind = (
  store: TestChildStore,
): RecordKind<"test_child", never, number> => ({
  name: "test_child",
  writes: undefined,
  readCurrent: (recordId): CurrentRecord<number> => {
    const value = store.find(recordId);
    if (value !== undefined) {
      return { status: "value", value };
    }
    return store.hasDeletion(recordId) ? { status: "deleted" } : { status: "absent" };
  },
});
