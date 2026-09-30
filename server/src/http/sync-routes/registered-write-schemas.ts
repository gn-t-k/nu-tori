import { accountSettingsWriteSchemas } from "../../account-settings/http/account-settings-http-kind";

// 登録簿の種類の書き込みのスキーマ。union の型を保つため、種類ごとの `writeSchemas` を型を保ったまま並べる。httpRecordKinds と同じ順に、1種類ずつ足す
export const registeredWriteSchemas = [...accountSettingsWriteSchemas] as const;
