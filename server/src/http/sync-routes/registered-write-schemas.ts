import { accountSettingsWriteSchemas } from "../../account-settings/http/account-settings-write-schemas";
import { weightRecordWriteSchemas } from "../../weight-record/http/weight-record-write-schemas";

// 登録簿の種類の書き込みのスキーマ。union の型を保つため、種類ごとの書き込みのスキーマを型を保ったまま名前の順に並べる。httpRecordKinds と同じ種類を、1種類ずつ足す
export const registeredWriteSchemas = [
  ...accountSettingsWriteSchemas,
  ...weightRecordWriteSchemas,
] as const;
