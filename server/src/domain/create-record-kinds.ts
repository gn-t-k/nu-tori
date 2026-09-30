import { createAccountSettingsKind } from "../account-settings/domain/create-account-settings-kind";
import type { RecordKindStores } from "./record-kind-stores";
import type { RecordKind, WriteBase } from "./sync-ledger/record-kind";

// 種類の登録簿。名前の順に、手で1行ずつ書く（生成しない）。ここにある種類は帳簿の道、無い種類は今の道で当てる
export const createRecordKinds = (stores: RecordKindStores) =>
  [createAccountSettingsKind(stores.accountSettings)] as const satisfies readonly RecordKind<
    string,
    WriteBase,
    unknown
  >[];
