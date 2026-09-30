import type { z } from "@hono/zod-openapi";
import type { SyncWrite } from "../../domain/sync-write";
import type { accountSettingsWriteSchemas } from "./account-settings-write-schemas";

export const toUpdateAccountSettingsWrite = ({
  id,
  accountSettings,
}: z.infer<(typeof accountSettingsWriteSchemas)[number]>): SyncWrite => ({
  id,
  type: "update_account_settings",
  accountSettings: { id: accountSettings.id, sendsUsageData: accountSettings.sendsUsageData },
});
