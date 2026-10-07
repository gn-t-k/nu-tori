import type { SyncWriteOutcome } from "../sync-write-outcome";
import type { WriteDecision } from "./record-kind";
import type { WriteKind } from "./write-kind";

// 何も書かない書き込みの決定（受け付けない、今の値と同じ、捨てる）。帳簿は控えだけを書き、変更の並びに載せない
export const decideWithoutChange = (
  writeKind: WriteKind,
  recordId: string,
  outcome: SyncWriteOutcome,
): WriteDecision => ({
  writeKind,
  recordId,
  outcome,
  changedRecordId: undefined,
  addedChanges: [],
  usageEvents: [],
  commit: () => undefined,
});
