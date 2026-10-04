import type { CurrentRecord } from "./current-record";

// 今の値が absent になるのは、記録が無くなったことを届ける種類（RecordKind の whenGone が absence）だけ
export type LedgerChange<TRecordType extends string, TValue> = {
  sequence: number;
  recordType: TRecordType;
  recordId: string;
  current: CurrentRecord<TValue>;
};
