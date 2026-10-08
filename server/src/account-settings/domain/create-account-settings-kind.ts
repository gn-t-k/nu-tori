import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { AccountSettings } from "./account-settings";
import type { AccountSettingsStore } from "./account-settings-store";
import type { AccountSettingsWrite } from "./account-settings-write";

// アカウントの設定の種類。記録が無くても直す書き込みで送り、無ければ作る。受け付けない値は無い
export const createAccountSettingsKind = (
  store: AccountSettingsStore,
): RecordKind<"account_settings", AccountSettingsWrite, AccountSettings> => ({
  name: "account_settings",
  writes: {
    isWrite: (write): write is AccountSettingsWrite => write.type === "update_account_settings",
    decide: ({ accountSettings }) => {
      const current = store.find();
      return {
        result: "applied",
        writeKind: "update",
        // 記録は1件なので、あればその ID で控えと変更を並べる
        recordId: current?.id ?? accountSettings.id,
        addedChanges: [],
        usageEvents: [],
        commit: (receiptId) => {
          if (current === undefined) {
            store.insert(accountSettings);
          } else {
            store.update(accountSettings.sendsUsageData);
          }
          store.insertChange({ receiptId, sendsUsageData: accountSettings.sendsUsageData });
        },
      };
    },
  },
  follows: undefined,
  whenGone: "never",
  readCurrent: () => {
    const current = store.find();
    return current === undefined ? { status: "absent" } : { status: "value", value: current };
  },
});
