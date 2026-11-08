import type { RecordId } from "../../record-id";
import type { CurrentRecord } from "../current-record";

// 置き場から記録の今の値を読む。値があれば値を、無ければ削除の印があるかで削除の印か無いかを返す。
// 消えない種類の置き場は hasDeletion を持たないので、値が無ければ無いと返す
export const readStoredRecord = <TValue>(
  store: {
    find: (recordId: RecordId) => TValue | undefined;
    hasDeletion?: (recordId: RecordId) => boolean;
  },
  recordId: RecordId,
): CurrentRecord<TValue> => {
  const value = store.find(recordId);
  if (value !== undefined) {
    return { status: "value", value };
  }
  return store.hasDeletion?.(recordId) === true ? { status: "deleted" } : { status: "absent" };
};
