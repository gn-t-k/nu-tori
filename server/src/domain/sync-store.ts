import type { AccountSettings } from "./account-settings";
import type { RecordType } from "./record-type";
import type { SyncClientState } from "./sync-client-state";
import type {
  CreateWeightRecordOutcome,
  SourceDeletedWeightRecordOutcome,
  SyncWriteOutcome,
  UpdateWeightRecordOutcome,
} from "./sync-write-outcome";
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
  insertWriteReceipt: (
    receipt: {
      writeId: string;
      requestLogId: string;
      positionInRequest: number;
      recordId: string;
    } & (
      | { kind: "create"; recordType: "weight_record"; outcome: CreateWeightRecordOutcome }
      | { kind: "update"; recordType: "weight_record"; outcome: UpdateWeightRecordOutcome }
      | {
          kind: "source_deleted";
          recordType: "weight_record";
          outcome: SourceDeletedWeightRecordOutcome;
        }
      | { kind: "update"; recordType: "account_settings"; outcome: { result: "applied" } }
    ),
  ) => void;
  findWeightRecord: (id: string) => WeightRecord | undefined;
  existsImportedSample: (healthkitSampleUuid: string) => boolean;
  existsWeightRecordDeletion: (recordId: string) => boolean;
  insertWeightRecord: (record: WeightRecord) => void;
  updateWeightRecord: (
    id: string,
    correction: Pick<WeightRecord, "weightKg" | "measuredAt" | "timeZone" | "version">,
  ) => void;
  deleteWeightRecord: (id: string) => void;
  insertWeightRecordDeletion: (writeId: string) => void;
  findAccountSettings: () => AccountSettings | undefined;
  insertAccountSettings: (settings: AccountSettings) => void;
  updateAccountSettings: (sendsUsageData: boolean) => void;
  insertAccountSettingChange: (change: { writeId: string; sendsUsageData: boolean }) => void;
  insertRecordChange: (change: {
    recordType: RecordType;
    recordId: string;
    writeId: string;
  }) => void;
  findLatestChangePerRecord: (
    afterSequence: number,
    limit: number,
  ) => { sequence: number; recordType: RecordType; recordId: string }[];
};
