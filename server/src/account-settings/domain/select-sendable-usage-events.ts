import type { UsageEvent } from "../../domain/usage-event";
import type { AccountSettingsStore } from "./account-settings-store";

// 利用状況を送らない人の出来事を、アカウントから出る前に落とす。端末がまだ設定を送っていなければ、既定のオンとして扱う。
// 出来事が無ければ設定を読まない（記録を消したあとの答えでは、表ごと消えていて読めない）
export const selectSendableUsageEvents = (
  accountSettings: AccountSettingsStore,
  events: readonly UsageEvent[],
): readonly UsageEvent[] =>
  events.length > 0 && (accountSettings.find()?.sendsUsageData ?? true) ? events : [];
