import type { AccountSettings } from "./account-settings";
import type { WeightRecord } from "./weight-record";

export type SyncChange = { sequence: number } & (
  | { type: "weight_record"; weightRecord: WeightRecord }
  | { type: "account_settings"; accountSettings: AccountSettings }
);
