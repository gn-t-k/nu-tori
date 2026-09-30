import { accountSettingsTables } from "../account-settings/durable-object/account-settings-tables";
import { weightRecordTables } from "../weight-record/durable-object/weight-record-tables";
import { firstSignInTables } from "./first-sign-in-tables";
import { syncLedgerTables } from "./sync-ledger-tables";

// Durable Object の全部の表。置き場のテストの行の作成と、宣言と移行のずれのテストが読む
export const durableObjectTables = {
  ...firstSignInTables,
  ...syncLedgerTables,
  ...weightRecordTables,
  ...accountSettingsTables,
};
