import { updateAccountSettingsWriteSchema } from "./account-settings-write-schema";

// アカウントの設定の書き込みのスキーマ。型を保つため as const で並べる
export const accountSettingsWriteSchemas = [updateAccountSettingsWriteSchema] as const;
