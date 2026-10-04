import type { AccountSettings } from "../domain/account-settings";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { accountSettingsRecordSchema } from "./account-settings-record-schema";
import { accountSettingsWriteSchemas } from "./account-settings-write-schemas";
import { toAccountSettingsRecord } from "./to-account-settings-record";
import { toUpdateAccountSettingsWrite } from "./to-account-settings-write";

export const accountSettingsHttpKind: HttpRecordKind<
  AccountSettings,
  (typeof accountSettingsWriteSchemas)[number],
  typeof accountSettingsRecordSchema
> = {
  writes: { schemas: accountSettingsWriteSchemas, toWrite: toUpdateAccountSettingsWrite },
  keepsDeletionMarks: false,
  recordSchema: accountSettingsRecordSchema,
  toRecord: toAccountSettingsRecord,
};
