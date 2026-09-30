import type { SyncClientState } from "../sync-client-state";
import type { SyncWriteOutcome } from "../sync-write-outcome";
import type { WriteKind } from "./record-kind";

// 帳簿の置き場。種類の中身は知らず、要求の控え・書き込みの控え・変更の並びだけを持つ
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
  findWriteOutcome: (writeId: string) => SyncWriteOutcome | undefined;
  insertWriteReceipt: (receipt: {
    writeId: string;
    requestLogId: string;
    positionInRequest: number;
    kind: WriteKind;
    recordType: TRecordType;
    recordId: string;
    outcome: SyncWriteOutcome;
  }) => void;
  insertRecordChange: (change: {
    recordType: TRecordType;
    recordId: string;
    writeId: string;
  }) => void;
  findLatestChangePerRecord: (
    afterSequence: number,
    limit: number,
  ) => { sequence: number; recordType: TRecordType; recordId: string }[];
};
