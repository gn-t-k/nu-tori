import { accountSettingsHttpKind } from "../../account-settings/http/account-settings-http-kind";
import { weightRecordHttpKind } from "../../weight-record/http/weight-record-http-kind";
import type { HttpRecordKind } from "./http-record-kind";

// 受け口から見た種類の登録簿。名前の順に、手で1行ずつ書く（生成しない）
export const httpRecordKinds: readonly HttpRecordKind[] = [
  accountSettingsHttpKind,
  weightRecordHttpKind,
];
