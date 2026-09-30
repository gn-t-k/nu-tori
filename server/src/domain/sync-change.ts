import type { AccountSettings } from "../account-settings/domain/account-settings";
import type { WeightRecord } from "../weight-record/domain/weight-record";
import type { createRecordKinds } from "./create-record-kinds";
import type { NameOfKind } from "./sync-ledger/record-kind";
import type { LedgerChange } from "./sync-ledger/sync-ledger";

// 変更は、登録簿の種類の分と、今の道で読む分を合わせたもの
export type SyncChange = LedgerChange<RegisteredRecordType, unknown> | LegacySyncChange;

export type RegisteredRecordType = NameOfKind<ReturnType<typeof createRecordKinds>[number]>;

export type LegacySyncChange = { sequence: number } & (
  | { type: "weight_record"; weightRecord: WeightRecord }
  | { type: "weight_record_deletion"; recordId: string }
  | { type: "account_settings"; accountSettings: AccountSettings }
);
