import type { SyncWriteOutcome } from "../sync-write-outcome";
import type { RejectedRecord } from "./rejected-record";

export type PushedResult<TRecordType extends string, TValue> = {
  writeId: string;
  outcome: SyncWriteOutcome;
  // outcome が rejected のときだけ付く。要求の書き込みを全部当て終えた時点の値
  rejectedRecord: RejectedRecord<TRecordType, TValue> | undefined;
};
