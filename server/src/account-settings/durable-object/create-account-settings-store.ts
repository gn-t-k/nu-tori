import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { AccountSettingsStore } from "../domain/account-settings-store";
import { accountSettingsTables } from "./account-settings-tables";

const { accountSettings, accountSettingChanges } = accountSettingsTables;

export const createAccountSettingsStore = (db: DrizzleSqliteDODatabase): AccountSettingsStore => ({
  find: () =>
    db
      .select({ id: accountSettings.id, sendsUsageData: accountSettings.sendsUsageData })
      .from(accountSettings)
      .get(),
  insert: ({ id, sendsUsageData }) => {
    db.insert(accountSettings).values({ id, sendsUsageData }).run();
  },
  update: (sendsUsageData) => {
    db.update(accountSettings).set({ sendsUsageData }).run();
  },
  insertChange: ({ receiptId, sendsUsageData }) => {
    db.insert(accountSettingChanges)
      .values({ syncWriteReceiptId: receiptId.value, sendsUsageData })
      .run();
  },
});
