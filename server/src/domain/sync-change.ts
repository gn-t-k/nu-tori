import type { AccountSettings } from "../account-settings/domain/account-settings";
import type { WeightRecord } from "../weight-record/domain/weight-record";

export type SyncChange = { sequence: number } & (
  | { type: "weight_record"; weightRecord: WeightRecord }
  | { type: "weight_record_deletion"; recordId: string }
  | { type: "account_settings"; accountSettings: AccountSettings }
);
