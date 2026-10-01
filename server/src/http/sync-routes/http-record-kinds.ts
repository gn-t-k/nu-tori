import { accountSettingsHttpKind } from "../../account-settings/http/account-settings-http-kind";
import type { RecordType } from "../../domain/record-type";
import { weightRecordHttpKind } from "../../weight-record/http/weight-record-http-kind";
import type { HttpRecordKind } from "./http-record-kind";

// 受け口から見た種類の登録簿。RecordType をキーにするので、種類を足して行を足し忘れるとコンパイルが落ちる
export const httpRecordKinds: { [K in RecordType]: HttpRecordKind } = {
  account_settings: accountSettingsHttpKind,
  weight_record: weightRecordHttpKind,
};
