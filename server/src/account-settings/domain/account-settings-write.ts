import type { AccountSettings } from "./account-settings";

export type AccountSettingsWrite = {
  id: string;
  type: "update_account_settings";
  accountSettings: AccountSettings;
};
