import type { RecordId } from "../record-id";
import type { CurrentRecord } from "../sync-ledger/current-record";
import type { RecordChangeTarget } from "../sync-ledger/record-change-target";

// 見張る種類。今の値を読めればよい
export type WatchedKind<TName extends string> = {
  name: TName;
  readCurrent(recordId: RecordId): CurrentRecord<unknown>;
};

// ほかの記録から決まる記録を、書く前と書いたあとで比べて、変わった記録にだけ変更を足す。
// 書く前に watch で記録を覚え（同じ記録は初めの1回だけ）、書き終えたら addChanges を1回呼ぶ。足す順は、覚えた順。
// 値は JSON にして比べる。種類が同じ形で値を組むので、欄の順もそろう
export const watchCurrentRecords = <TName extends string>(
  addChange: (change: RecordChangeTarget<TName>) => void,
): {
  watch: (kind: WatchedKind<TName>, recordId: RecordId) => void;
  addChanges: () => void;
} => {
  const watched = new Map<
    string,
    { kind: WatchedKind<TName>; recordId: RecordId; before: CurrentRecord<unknown> }
  >();
  return {
    watch: (kind, recordId) => {
      const key = `${kind.name}:${recordId}`;
      if (!watched.has(key)) {
        watched.set(key, { kind, recordId, before: kind.readCurrent(recordId) });
      }
    },
    addChanges: () => {
      for (const { kind, recordId, before } of watched.values()) {
        if (!isSameRecord(before, kind.readCurrent(recordId))) {
          addChange({ recordType: kind.name, recordId });
        }
      }
    },
  };
};

const isSameRecord = (a: CurrentRecord<unknown>, b: CurrentRecord<unknown>): boolean =>
  a.status === "value" && b.status === "value"
    ? JSON.stringify(a.value) === JSON.stringify(b.value)
    : a.status === b.status;
