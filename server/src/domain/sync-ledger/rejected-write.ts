import type { RejectionReason } from "../rejection-reason";
import type { WriteKind } from "./write-kind";

export type RejectedWrite<TRecordType extends string> = {
  writeKind: WriteKind;
  recordType: TRecordType;
  reason: RejectionReason;
};
