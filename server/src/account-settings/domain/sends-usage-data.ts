import type { AccountSettingsStore } from "./account-settings-store";

// 利用状況を送るか。端末がまだ設定を送っていなければ、既定のオンとして扱う
export const sendsUsageData = (store: AccountSettingsStore): boolean =>
  store.find()?.sendsUsageData ?? true;
