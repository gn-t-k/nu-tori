import type { RecordId } from "../../record-id";
import type { SyncWriteOutcome } from "../../sync-write-outcome";
import type { LedgerStore } from "../ledger-store";

// 帳簿の単体テスト用のメモリの置き場。operations に書いた順を残す（控えと結ばない変更は added_change）
export const createMemoryLedgerStore = <TRecordType extends string>(
  operations: string[],
): LedgerStore<TRecordType> => {
  const requestReceivedAts: Date[] = [];
  const receipts = new Map<
    string,
    { outcome: SyncWriteOutcome; recordType: TRecordType; recordId: RecordId }
  >();
  const changes: { sequence: number; recordType: TRecordType; recordId: RecordId }[] = [];
  return {
    transaction: (run) => run(),
    findLatestRequestReceivedAt: () => requestReceivedAts.at(-1),
    insertPushRequestLog: ({ receivedAt }) => {
      operations.push("request_log");
      requestReceivedAts.push(receivedAt);
    },
    insertPullRequestLog: ({ receivedAt }) => {
      operations.push("request_log");
      requestReceivedAts.push(receivedAt);
    },
    findWriteReceipt: (writeId) => receipts.get(writeId),
    insertWriteReceipt: ({ writeId, outcome, recordType, recordId }) => {
      operations.push("receipt");
      receipts.set(writeId, { outcome, recordType, recordId });
    },
    insertRecordChange: ({ recordType, recordId, writeId }) => {
      operations.push(writeId === undefined ? "added_change" : "change");
      changes.push({ sequence: changes.length + 1, recordType, recordId });
    },
    findLatestChangePerRecord: (afterSequence, limit) => {
      const latest = new Map<string, (typeof changes)[number]>();
      for (const change of changes.filter(({ sequence }) => sequence > afterSequence)) {
        latest.set(`${change.recordType}:${change.recordId}`, change);
      }
      return [...latest.values()].toSorted((a, b) => a.sequence - b.sequence).slice(0, limit);
    },
  };
};
