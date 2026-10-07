import type { RecordId } from "../record-id";
import type { SyncClientState } from "../sync-client-state";
import type { SyncWriteOutcome } from "../sync-write-outcome";
import type { WriteKind } from "./write-kind";

export type LedgerStore<TRecordType extends string> = {
  transaction: <T>(run: () => T) => T;
  findLatestRequestReceivedAt: () => Date | undefined;
  insertPushRequestLog: (log: {
    id: string;
    receivedAt: Date;
    clientState: SyncClientState;
    isFinalBatch: boolean;
  }) => void;
  insertPullRequestLog: (log: {
    id: string;
    receivedAt: Date;
    clientState: SyncClientState;
    afterSequence: number;
  }) => void;
  // 同じ書き込みの ID が再び届いたときに、最初の結果と、その書き込みが指した記録を返す
  findWriteReceipt: (
    writeId: string,
  ) => { outcome: SyncWriteOutcome; recordType: TRecordType; recordId: RecordId } | undefined;
  insertWriteReceipt: (receipt: {
    writeId: string;
    requestLogId: string;
    positionInRequest: number;
    kind: WriteKind;
    recordType: TRecordType;
    recordId: RecordId;
    outcome: SyncWriteOutcome;
  }) => void;
  // 書き込みが直接変えた記録の変更だけを、その書き込みの控えと結ぶ。ほかは writeId を undefined にする
  insertRecordChange: (change: {
    recordType: TRecordType;
    recordId: RecordId;
    writeId: string | undefined;
  }) => void;
  findLatestChangePerRecord: (
    afterSequence: number,
    limit: number,
  ) => { sequence: number; recordType: TRecordType; recordId: RecordId }[];
};
