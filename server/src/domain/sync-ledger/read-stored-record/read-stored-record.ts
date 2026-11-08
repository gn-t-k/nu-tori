import type { RecordId } from "../../record-id";
import type { CurrentRecord } from "../current-record";

// 消えたことを削除の印で届ける種類（whenGone が deletion_mark）の今の値を、その種類の置き場から読む。
// 消えない種類に使わせないため hasDeletion を必須にする。省けると、置き場を包み直したときに削除の印を見落とし、消した記録が無いと返って生き返る
export const readStoredRecord = <TValue>(
  store: {
    find: (recordId: RecordId) => TValue | undefined;
    hasDeletion: (recordId: RecordId) => boolean;
  },
  recordId: RecordId,
): CurrentRecord<TValue> => {
  const value = store.find(recordId);
  if (value !== undefined) {
    return { status: "value", value };
  }
  return store.hasDeletion(recordId) ? { status: "deleted" } : { status: "absent" };
};
