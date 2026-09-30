import type { WriteReceiptId } from "../../domain/sync-ledger/write-receipt-id";
import type { AccountSettings } from "./account-settings";

export type AccountSettingsStore = {
  find: () => AccountSettings | undefined;
  insert: (settings: AccountSettings) => void;
  update: (sendsUsageData: boolean) => void;
  // 切り替えたあとの値を、書き込みの控えに紐づけて残す
  insertChange: (change: { receiptId: WriteReceiptId; sendsUsageData: boolean }) => void;
};
