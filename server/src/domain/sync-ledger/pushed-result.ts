import type { SyncWriteOutcome } from "../sync-write-outcome";
import type { CurrentRecord } from "./current-record";

export type PushedResult<TRecordType extends string, TValue> = {
  writeId: string;
  outcome: SyncWriteOutcome;
  // outcome が rejected のときだけ付く。要求の書き込みを全部当て終えた時点の値
  rejectedRecord: RejectedRecord<TRecordType, TValue> | undefined;
};

// 受け付けなかった書き込みに添える、その記録のサーバーの今の値
export type RejectedRecord<TRecordType extends string, TValue> = {
  recordType: TRecordType;
  recordId: string;
  current: CurrentRecord<TValue>;
};
