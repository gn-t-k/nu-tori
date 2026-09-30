import type { PresentRecord } from "./current-record";

export type LedgerChange<TRecordType extends string, TValue> = {
  sequence: number;
  recordType: TRecordType;
  recordId: string;
  current: PresentRecord<TValue>;
};
