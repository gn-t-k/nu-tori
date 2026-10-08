import type { RecordId } from "../record-id";
import type { RejectionReason } from "../rejection-reason";
import type { WriteDecision } from "./record-kind";
import type { WriteKind } from "./write-kind";

// 何も書かずに受け付けない決定
export const rejectWrite = (
  writeKind: WriteKind,
  recordId: RecordId,
  reason: RejectionReason,
): Extract<WriteDecision, { result: "rejected" }> => ({
  result: "rejected",
  writeKind,
  recordId,
  reason,
});
