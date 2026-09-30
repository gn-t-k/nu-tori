import type { z } from "@hono/zod-openapi";
import type { SyncWrite } from "../../domain/sync-write";
import type { updateAccountSettingsWriteSchema } from "./account-settings-write-schema";

export const toUpdateAccountSettingsWrite = ({
  id,
  accountSettings,
}: z.infer<typeof updateAccountSettingsWriteSchema>): SyncWrite => ({
  id,
  type: "update_account_settings",
  accountSettings: { id: accountSettings.id, sendsUsageData: accountSettings.sendsUsageData },
});
