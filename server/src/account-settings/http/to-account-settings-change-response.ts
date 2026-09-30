import type { AccountSettings } from "../domain/account-settings";

export const toAccountSettingsChangeResponse = (
  sequence: number,
  accountSettings: AccountSettings,
) => ({
  sequence,
  kind: "account_settings",
  recordId: accountSettings.id,
  record: { id: accountSettings.id, sendsUsageData: accountSettings.sendsUsageData },
});
