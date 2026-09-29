import type { AccountSettings } from "./account-settings";
import type { RecordType } from "./record-type";
import type { SyncClientState } from "./sync-client-state";
import type { SyncWriteOutcome } from "./sync-write-outcome";
import type { WeightRecord } from "./weight-record";

export type SyncStore = {
  transaction: <T>(run: () => T) => T;
  findStartedOn: () => string | undefined;
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
    kind: "create" | "update";
    recordType: RecordType;
    recordId: string;
    outcome: SyncWriteOutcome;
  }) => void;
  findWeightRecord: (id: string) => WeightRecord | undefined;
  existsImportedSample: (healthkitSampleUuid: string) => boolean;
  insertWeightRecord: (record: WeightRecord) => void;
  updateWeightRecord: (
    id: string,
    correction: Pick<WeightRecord, "weightKg" | "measuredAt" | "timeZone" | "version">,
  ) => void;
  findAccountSettings: () => AccountSettings | undefined;
  insertAccountSettings: (settings: AccountSettings) => void;
  updateAccountSettings: (sendsUsageData: boolean) => void;
  insertAccountSettingChange: (change: { writeId: string; sendsUsageData: boolean }) => void;
  insertRecordChange: (change: {
    recordType: RecordType;
    recordId: string;
    writeId: string;
  }) => void;
  // 記録ごとにいちばん大きい通し番号を1つ添え、その番号の順に返す
  findRecordChanges: (
    afterSequence: number,
    limit: number,
  ) => { sequence: number; recordType: RecordType; recordId: string }[];
};
