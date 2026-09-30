import { createAccountSettingsKind } from "../account-settings/domain/create-account-settings-kind";
import { createWeightRecordKind } from "../weight-record/domain/create-weight-record-kind";
import type { RecordKindStores } from "./record-kind-stores";
import type { RecordKind } from "./sync-ledger/record-kind";
import type { WriteBase } from "./sync-ledger/write-base";

// 種類の登録簿。名前の順に、手で1行ずつ書く（生成しない）。ここにある種類は帳簿の道、無い種類は今の道で当てる
export const createRecordKinds = (stores: RecordKindStores) =>
  [
    createAccountSettingsKind(stores.accountSettings),
    createWeightRecordKind(stores.weightRecord),
  ] as const satisfies readonly RecordKind<string, WriteBase, unknown>[];
