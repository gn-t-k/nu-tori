import { z } from "@hono/zod-openapi";
import { recordIdSchema } from "../../domain/record-id";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";
import type { AccountSettings } from "../domain/account-settings";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
const accountSettingsRecordSchema = z
  .object({ id: z.string(), sendsUsageData: z.boolean() })
  .openapi({
    description: "kind が account_settings の変更の record。アカウントに1つで、削除の印は無い",
  });

const updateAccountSettingsWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("update_account_settings"),
    accountSettings: z.object({
      id: recordIdSchema.meta({
        description:
          "端末で振ったアカウントの設定の ID。アカウント ID から名前空間を分けた UUID v5 で出す。サーバーは ID では探さず、アカウントに1件の記録として持つ",
      }),
      sendsUsageData: z.boolean(),
    }),
  })
  .openapi("UpdateAccountSettingsWrite");

// アカウントの設定の書き込みのスキーマ。型を保つため as const で並べる
const accountSettingsWriteSchemas = [updateAccountSettingsWriteSchema] as const;

export const accountSettingsHttpKind: HttpRecordKind<
  AccountSettings,
  (typeof accountSettingsWriteSchemas)[number],
  typeof accountSettingsRecordSchema
> = {
  writes: {
    schemas: accountSettingsWriteSchemas,
    toWrite: ({ id, accountSettings }) => ({
      id,
      type: "update_account_settings",
      accountSettings: { id: accountSettings.id, sendsUsageData: accountSettings.sendsUsageData },
    }),
  },
  recordSchema: accountSettingsRecordSchema,
  toRecord: (value) => ({ id: value.id, sendsUsageData: value.sendsUsageData }),
};
