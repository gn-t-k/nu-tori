import type { CurrentRecord } from "./current-record";

// 受け付けなかった書き込みに添える、その記録のサーバーの今の値
export type RejectedRecord<TRecordType extends string, TValue> = {
  recordType: TRecordType;
  recordId: string;
  current: CurrentRecord<TValue>;
};
