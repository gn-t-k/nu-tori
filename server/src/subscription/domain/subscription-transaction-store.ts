import type { RecordId } from "../../domain/record-id";
import type {
  AppStoreSubscriptionEnvironment,
  SubscriptionTransactionReason,
  SubscriptionTransactionReportTrigger,
} from "./subscription";

// サブスクリプションと取引と受け取りを書く置き場。どの表も書き足すだけ
export type SubscriptionTransactionStore = {
  hasReceipt: (id: RecordId) => boolean;
  insertReceipt: (receipt: { id: RecordId; receivedAt: Date }) => void;
  findAppStoreSubscriptionId: (key: AppStoreSubscriptionKey) => RecordId | undefined;
  // サブスクリプションと、その App Store の出どころを書く
  insertAppStoreSubscription: (subscription: { id: RecordId } & AppStoreSubscriptionKey) => void;
  findTransactionIdByAppStoreTransactionId: (appStoreTransactionId: string) => RecordId | undefined;
  // 取引と、その App Store の取引を書く
  insertAppStoreTransaction: (transaction: {
    id: RecordId;
    subscriptionId: RecordId;
    subscriptionReceiptId: RecordId;
    transactionReason: SubscriptionTransactionReason;
    purchasedAt: Date;
    expiresAt: Date;
    appStoreTransactionId: string;
    appStoreProductId: string;
  }) => void;
  insertTransactionReportReceipt: (receipt: {
    subscriptionReceiptId: RecordId;
    subscriptionTransactionId: RecordId;
    reportTrigger: SubscriptionTransactionReportTrigger;
  }) => void;
};

export type AppStoreSubscriptionKey = {
  environment: AppStoreSubscriptionEnvironment;
  appStoreOriginalTransactionId: string;
};
