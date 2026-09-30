import type { AccountSettings } from "../account-settings/domain/account-settings";
import type { WeightRecord } from "../weight-record/domain/weight-record";

export type SyncWrite = { id: string } & (
  | { type: "create_weight_record"; weightRecord: Omit<WeightRecord, "version"> }
  | { type: "update_weight_record"; weightRecord: Omit<WeightRecord, "imported"> }
  | { type: "source_deleted_weight_record"; weightRecordId: string }
  | { type: "update_account_settings"; accountSettings: AccountSettings }
);
