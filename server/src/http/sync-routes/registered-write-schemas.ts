import { accountSettingsWriteSchemas } from "../../account-settings/http/account-settings-http-kind";
import { weightRecordWriteSchemas } from "../../weight-record/http/weight-record-write-schemas";

// 登録簿の種類の書き込みのスキーマ。union の型を保つため、種類ごとの `writeSchemas` を型を保ったまま並べる。httpRecordKinds と同じ種類を、1種類ずつ足す
// 並びは書き出す openapi.json の oneOf の並びになる。今の並び（体重記録 → アカウントの設定）を保つため、ここだけ名前の順にしていない
export const registeredWriteSchemas = [
  ...weightRecordWriteSchemas,
  ...accountSettingsWriteSchemas,
] as const;
