import type { PresentRecord } from "./present-record";

export type LedgerChange<TRecordType extends string, TValue> = {
  sequence: number;
  recordType: TRecordType;
  recordId: string;
  current: PresentRecord<TValue>;
};
