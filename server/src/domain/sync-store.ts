import type { AccountSettings } from "../account-settings/domain/account-settings";
import type { RecordType } from "./record-type";
import type { LedgerStore } from "./sync-ledger/ledger-store";
import type { WeightRecord } from "../weight-record/domain/weight-record";

// 帳簿の置き場に、今の道で当てる種類（体重記録、アカウントの設定）の置き場を足したもの
export type SyncStore = LedgerStore<RecordType> & {
  findStartedOn: () => string | undefined;
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
};
