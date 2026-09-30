import type { SyncClientState } from "../sync-client-state";
import type { RejectionReason, SyncWriteOutcome } from "../sync-write-outcome";
import type { LedgerStore } from "./ledger-store";
import type { CurrentRecord, PresentRecord, RecordKind, WriteBase, WriteKind } from "./record-kind";

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

// 受け付けなかった書き込みに添える、その記録のサーバーの今の値
export type RejectedRecord<TRecordType extends string, TValue> = {
  recordType: TRecordType;
  recordId: string;
  current: CurrentRecord<TValue>;
};

export type PushedResult<TRecordType extends string, TValue> = {
  writeId: string;
  outcome: SyncWriteOutcome;
  // outcome が rejected のときだけ付く。要求の書き込みを全部当て終えた時点の値
  rejectedRecord: RejectedRecord<TRecordType, TValue> | undefined;
};

// 登録簿にない種類の書き込み・変更は、型で来ない。実行時に来たら不具合として投げる
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

  const push = (request: {
    clientState: SyncClientState;
    writes: readonly TWrite[];
    isFinalBatch: boolean;
    receivedAt: Date;
  }) =>
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
      const settled = request.writes.map((write, positionInRequest) => {
        const previousReceipt = store.findWriteReceipt(write.id);
        if (previousReceipt !== undefined) {
          return {
            writeId: write.id,
            outcome: previousReceipt.outcome,
            target: { recordType: previousReceipt.recordType, recordId: previousReceipt.recordId },
          };
        }
        const owner = kinds.find((kind) => kind.writes?.isWrite(write) === true);
        if (owner?.writes === undefined) {
          throw new Error(`登録簿に無い書き込み: ${write.type}`);
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
        return {
          writeId: write.id,
          outcome: decision.outcome,
          target: { recordType: owner.name, recordId: decision.recordId },
        };
      });
      // 今の値は、要求の書き込みを全部当て終えてから読む。同じ書き込みの ID が再び届いたときも同じ（控えには持たない）
      const results = settled.map(
        ({ writeId, outcome, target }): PushedResult<TRecordType, TValue> => ({
          writeId,
          outcome,
          rejectedRecord:
            outcome.result === "rejected"
              ? {
                  recordType: target.recordType,
                  recordId: target.recordId,
                  current: readCurrentOf(target.recordType, target.recordId),
                }
              : undefined,
        }),
      );
      return { results, rejectedWrites, previousRequestReceivedAt };
    });

  const readCurrentOf = (recordType: TRecordType, recordId: string): CurrentRecord<TValue> => {
    const owner = kinds.find((kind) => kind.name === recordType);
    if (owner === undefined) {
      throw new Error(`登録簿に無い種類の控え: ${recordType}`);
    }
    return owner.readCurrent(recordId);
  };

  const pull = (request: {
    clientState: SyncClientState;
    afterSequence: number;
    receivedAt: Date;
  }) =>
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
        .map((change): LedgerChange<TKindName, TValue> => {
          const owner = kinds.find((kind) => kind.name === change.recordType);
          if (owner === undefined) {
            throw new Error(`登録簿に無い種類の変更: ${change.recordType}`);
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
