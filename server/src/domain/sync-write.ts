import type { AccountSettings } from "../account-settings/domain/account-settings";
import type { WeightRecord } from "../weight-record/domain/weight-record";
import type { createRecordKinds } from "./create-record-kinds";
import type { WriteOfKind } from "./sync-ledger/record-kind";

// 書き込みは、登録簿の種類の分と、今の道で当てる分を合わせたもの
export type SyncWrite = RegisteredSyncWrite | LegacySyncWrite;

type RegisteredSyncWrite = WriteOfKind<ReturnType<typeof createRecordKinds>[number]>;

export type LegacySyncWrite = { id: string } & (
  | { type: "create_weight_record"; weightRecord: Omit<WeightRecord, "version"> }
  | { type: "update_weight_record"; weightRecord: Omit<WeightRecord, "imported"> }
  | { type: "source_deleted_weight_record"; weightRecordId: string }
  | { type: "update_account_settings"; accountSettings: AccountSettings }
);
