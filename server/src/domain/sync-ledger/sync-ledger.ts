import type { SyncClientState } from "../sync-client-state";
import type { RejectionReason, SyncWriteOutcome } from "../sync-write-outcome";
import type { LedgerStore } from "./ledger-store";
import type { PresentRecord, RecordKind, WriteBase, WriteKind } from "./record-kind";

// 控えの ID は帳簿しか作れない。クラスの値は export せず型だけ出すので、外からは作れない
class WriteReceiptId {
  private constructor(readonly value: string) {}

  static issue(writeId: string): WriteReceiptId {
    return new WriteReceiptId(writeId);
  }
}
export type { WriteReceiptId };

export type RejectedWrite<TRecordType extends string> = {
  writeKind: WriteKind;
  recordType: TRecordType;
  reason: RejectionReason;
};

export type LedgerChange<TRecordType extends string, TValue> = {
  sequence: number;
  recordType: TRecordType;
  recordId: string;
  current: PresentRecord<TValue>;
};

// 登録簿にない種類の書き込み・変更は、呼び出し側の今の道が当てる
export const createSyncLedger = <
  TRecordType extends string,
  TKindName extends TRecordType,
  TWrite extends WriteBase,
  TValue,
>(
  store: LedgerStore<TRecordType>,
  kinds: readonly RecordKind<TKindName, TWrite, TValue>[],
) => {
  const changesPerPull = 500;

  const push = (
    request: {
      clientState: SyncClientState;
      writes: readonly TWrite[];
      isFinalBatch: boolean;
      receivedAt: Date;
    },
    applyUnregistered: (
      write: TWrite,
      position: { requestLogId: string; positionInRequest: number },
    ) => { outcome: SyncWriteOutcome; rejection: RejectedWrite<TRecordType> | undefined },
  ) =>
    store.transaction(() => {
      const previousRequestReceivedAt = store.findLatestRequestReceivedAt();
      const requestLogId = crypto.randomUUID();
      store.insertPushRequestLog({
        id: requestLogId,
        receivedAt: request.receivedAt,
        clientState: request.clientState,
        isFinalBatch: request.isFinalBatch,
      });
      const rejectedWrites: RejectedWrite<TRecordType>[] = [];
      const results = request.writes.map((write, positionInRequest) => {
        const previousOutcome = store.findWriteOutcome(write.id);
        if (previousOutcome !== undefined) {
          return { writeId: write.id, outcome: previousOutcome };
        }
        const owner = kinds.find((kind) => kind.writes?.isWrite(write) === true);
        if (owner?.writes === undefined) {
          const applied = applyUnregistered(write, { requestLogId, positionInRequest });
          if (applied.rejection !== undefined) {
            rejectedWrites.push(applied.rejection);
          }
          return { writeId: write.id, outcome: applied.outcome };
        }
        const decision = owner.writes.decide(write);
        store.insertWriteReceipt({
          writeId: write.id,
          requestLogId,
          positionInRequest,
          kind: decision.writeKind,
          recordType: owner.name,
          recordId: decision.recordId,
          outcome: decision.outcome,
        });
        decision.commit(WriteReceiptId.issue(write.id));
        if (decision.changedRecordId !== undefined) {
          store.insertRecordChange({
            recordType: owner.name,
            recordId: decision.changedRecordId,
            writeId: write.id,
          });
        }
        if (decision.outcome.result === "rejected") {
          rejectedWrites.push({
            writeKind: decision.writeKind,
            recordType: owner.name,
            reason: decision.outcome.reason,
          });
        }
        return { writeId: write.id, outcome: decision.outcome };
      });
      return { results, rejectedWrites, previousRequestReceivedAt };
    });

  const pull = <TUnregisteredChange>(
    request: { clientState: SyncClientState; afterSequence: number; receivedAt: Date },
    pullUnregistered: (found: {
      sequence: number;
      recordType: TRecordType;
      recordId: string;
    }) => TUnregisteredChange,
  ) =>
    store.transaction(() => {
      const previousRequestReceivedAt = store.findLatestRequestReceivedAt();
      store.insertPullRequestLog({
        id: crypto.randomUUID(),
        receivedAt: request.receivedAt,
        clientState: request.clientState,
        afterSequence: request.afterSequence,
      });
      const found = store.findLatestChangePerRecord(request.afterSequence, changesPerPull + 1);
      const changes = found
        .slice(0, changesPerPull)
        .map((change): LedgerChange<TKindName, TValue> | TUnregisteredChange => {
          const owner = kinds.find((kind) => kind.name === change.recordType);
          if (owner === undefined) {
            return pullUnregistered(change);
          }
          const current = owner.readCurrent(change.recordId);
          if (current.status === "absent") {
            throw new Error(
              `変更の並びが指す記録も削除の印も無い: ${owner.name} ${change.recordId}`,
            );
          }
          return {
            sequence: change.sequence,
            recordType: owner.name,
            recordId: change.recordId,
            current,
          };
        });
      return {
        changes,
        hasMore: found.length > changesPerPull,
        lastSequence: found.slice(0, changesPerPull).at(-1)?.sequence,
        previousRequestReceivedAt,
      };
    });

  return { push, pull };
};
