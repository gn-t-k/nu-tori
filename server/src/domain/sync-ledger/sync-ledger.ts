import type { SyncClientState } from "../sync-client-state";
import type { RejectionReason } from "../rejection-reason";
import type { UsageEvent } from "../usage-event";
import type { CurrentRecord } from "./current-record";
import type { LedgerChange } from "./ledger-change";
import type { LedgerStore } from "./ledger-store";
import type { PushedResult } from "./pushed-result";
import type { RecordChangeTarget } from "./record-change-target";
import type { RecordKind } from "./record-kind";
import type { WriteBase } from "./write-base";
import type { WriteKind } from "./write-kind";

export type { WriteReceiptId };

// 登録簿にない種類の書き込み・変更は、型で来ない。実行時に来たら不具合として投げる
export const createSyncLedger = <
  TRecordType extends string,
  TKindName extends TRecordType,
  TWrite extends WriteBase,
  TValue,
>(
  store: LedgerStore<TRecordType>,
  kinds: readonly RecordKind<TKindName, TWrite, TValue, TKindName>[],
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
      const usageEvents: UsageEvent[] = [];
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
        for (const added of decision.addedChanges) {
          store.insertRecordChange({ ...added, writeId: undefined });
        }
        usageEvents.push(...decision.usageEvents);
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
      return { results, rejectedWrites, usageEvents, previousRequestReceivedAt };
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
          if (current.status === "absent" && !owner.deliversAbsence) {
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

  // 受け口の要求やアラームが、端末の書き込みの外で記録を変えるときの入口。run が記録を書き、変えた記録を addChange で足す。
  // 変更は足した順に通し番号が付き、run の書き込みと1つのトランザクションに入る
  const changeOutsideWrites = <T>(
    run: (addChange: (change: RecordChangeTarget<TKindName>) => void) => T,
  ): T =>
    store.transaction(() =>
      run((change) => {
        store.insertRecordChange({ ...change, writeId: undefined });
      }),
    );

  return { push, pull, changeOutsideWrites };
};

// 控えの ID。作れるのは帳簿だけ（値を export していないので、ほかは組み立てられない）
class WriteReceiptId {
  // TypeScript の型は構造で比べるので、公開の欄だけだと `{ value: "..." }` のオブジェクトも控えの ID として通る。
  // 値を ES の private の欄に持たせ、帳簿が作ったものだけを通す
  readonly #value: string;

  private constructor(value: string) {
    this.#value = value;
  }

  get value(): string {
    return this.#value;
  }

  static issue(writeId: string): WriteReceiptId {
    return new WriteReceiptId(writeId);
  }
}

type RejectedWrite<TRecordType extends string> = {
  writeKind: WriteKind;
  recordType: TRecordType;
  reason: RejectionReason;
};
