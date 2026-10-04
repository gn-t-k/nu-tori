import type { z } from "@hono/zod-openapi";
import type { AccountSettings } from "../domain/account-settings";
import type { accountSettingsRecordSchema } from "./account-settings-record-schema";

export const toAccountSettingsRecord = (
  value: AccountSettings,
): z.input<typeof accountSettingsRecordSchema> => ({
  id: value.id,
  sendsUsageData: value.sendsUsageData,
});
