import { match } from "ts-pattern";
import { generateRecordId, type RecordId } from "../record-id";
import type { SyncClientState } from "../sync-client-state";
import type { SyncWriteOutcome } from "../sync-write-outcome";
import type { RejectionReason } from "../rejection-reason";
import type { UsageEvent } from "../usage-event";
import type { CurrentRecord } from "./current-record";
import type { LedgerChange } from "./ledger-change";
import type { LedgerStore } from "./ledger-store";
import type { PushedResult } from "./pushed-result";
import type { RecordChangeTarget } from "./record-change-target";
import type { RecordKind, WhenGone } from "./record-kind";
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
  kinds: readonly RecordKind<TKindName, TWrite, TValue, TKindName, TKindName>[],
) => {
  type Kind = (typeof kinds)[number];
  const changesPerPull = 500;

  const push = (request: {
    clientState: SyncClientState;
    writes: readonly TWrite[];
    isFinalBatch: boolean;
    receivedAt: Date;
  }) =>
    store.transaction(() => {
      const previousRequestReceivedAt = store.findLatestRequestReceivedAt();
      const requestLogId = generateRecordId();
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
          // 種類を探すのは受け付けなかったときだけにする。受け付けた書き込みの再送は、種類を登録簿から外したあとも通す
          return settle(write.id, previousReceipt.outcome, () => ({
            owner: findOwner(previousReceipt.recordType, "登録簿に無い種類の控え"),
            recordId: previousReceipt.recordId,
          }));
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
        const receiptId = WriteReceiptId.issue(write.id);
        decision.commit(receiptId);
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
        if (decision.outcome.result === "applied") {
          for (const follower of kinds) {
            if (follower.follows?.source !== owner.name) {
              continue;
            }
            for (const recordId of follower.follows.afterSourceApplied(receiptId)) {
              store.insertRecordChange({ recordType: follower.name, recordId, writeId: undefined });
            }
          }
        }
        usageEvents.push(...decision.usageEvents);
        if (decision.outcome.result === "rejected") {
          rejectedWrites.push({
            writeKind: decision.writeKind,
            recordType: owner.name,
            reason: decision.outcome.reason,
          });
        }
        return settle(write.id, decision.outcome, () => ({ owner, recordId: decision.recordId }));
      });
      // 今の値は、要求の書き込みを全部当て終えてから読む。同じ書き込みの ID が再び届いたときも同じ（控えには持たない）
      const results = settled.map(
        ({ writeId, outcome, rejectedTarget }): PushedResult<TRecordType, TValue> => ({
          writeId,
          outcome,
          rejectedRecord:
            rejectedTarget === undefined
              ? undefined
              : {
                  recordType: rejectedTarget.owner.name,
                  recordId: rejectedTarget.recordId,
                  current: readRejectedCurrent(rejectedTarget.owner, rejectedTarget.recordId),
                },
        }),
      );
      return { results, rejectedWrites, usageEvents, previousRequestReceivedAt };
    });

  const pull = (request: {
    clientState: SyncClientState;
    afterSequence: number;
    receivedAt: Date;
  }) =>
    store.transaction(() => {
      const previousRequestReceivedAt = store.findLatestRequestReceivedAt();
      store.insertPullRequestLog({
        id: generateRecordId(),
        receivedAt: request.receivedAt,
        clientState: request.clientState,
        afterSequence: request.afterSequence,
      });
      const found = store.findLatestChangePerRecord(request.afterSequence, changesPerPull + 1);
      const changes = found
        .slice(0, changesPerPull)
        .map((change): LedgerChange<TKindName, TValue> => {
          const owner = findOwner(change.recordType, "登録簿に無い種類の変更");
          return {
            sequence: change.sequence,
            recordType: owner.name,
            recordId: change.recordId,
            current: readPulledCurrent(owner, change.recordId),
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

  // 受け付けなかったときだけ、今の値を読む種類と記録を持たせる
  const settle = (
    writeId: string,
    outcome: SyncWriteOutcome,
    findRejectedTarget: () => { owner: Kind; recordId: RecordId },
  ) =>
    outcome.result === "rejected"
      ? { writeId, outcome, rejectedTarget: findRejectedTarget() }
      : { writeId, outcome, rejectedTarget: undefined };

  const findOwner = (recordType: TRecordType, missingMessage: string) => {
    const owner = kinds.find((kind) => kind.name === recordType);
    if (owner === undefined) {
      throw new Error(`${missingMessage}: ${recordType}`);
    }
    return owner;
  };

  // 受け付けなかった書き込みの記録は、まだ作られていないことがあるので、どの種類でも無いこと（absent）を返す
  const readRejectedCurrent = (owner: Kind, recordId: RecordId): CurrentRecord<TValue> => {
    const current = owner.readCurrent(recordId);
    match(current.status)
      .with("value", "absent", () => undefined)
      .with("deleted", () => ensureKeepsDeletionMarks(owner, recordId))
      .exhaustive();
    return current;
  };

  const readPulledCurrent = (owner: Kind, recordId: RecordId): CurrentRecord<TValue> => {
    const current = owner.readCurrent(recordId);
    match(current.status)
      .with("value", () => undefined)
      .with("deleted", () => ensureKeepsDeletionMarks(owner, recordId))
      .with("absent", () => ensureDeliversAbsence(owner, recordId))
      .exhaustive();
    return current;
  };

  return { push, pull, changeOutsideWrites };
};

// 今の値が種類の whenGone と食い違うのは不具合なので投げる
const ensureKeepsDeletionMarks = (
  owner: { name: string; whenGone: WhenGone },
  recordId: string,
): void =>
  match(owner.whenGone)
    .with("deletion_mark", () => undefined)
    .with("absence", "never", () => {
      throw new Error(`削除の印を持たない種類の削除の印: ${owner.name} ${recordId}`);
    })
    .exhaustive();

const ensureDeliversAbsence = (
  owner: { name: string; whenGone: WhenGone },
  recordId: string,
): void =>
  match(owner.whenGone)
    .with("absence", () => undefined)
    .with("deletion_mark", "never", () => {
      throw new Error(`変更の並びが指す記録も削除の印も無い: ${owner.name} ${recordId}`);
    })
    .exhaustive();

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
