import type { RecordId } from "../../domain/record-id";
import type { AppStoreSubscriptionKey } from "./app-store-subscription-key";
import type {
  SubscriptionTransactionReason,
  SubscriptionTransactionReportTrigger,
} from "./subscription-transaction-fact";

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
  // 取引に取り消しの時刻の取り消しがあるか（戻したものを含む）
  hasRevocationAt: (subscriptionTransactionId: RecordId, revokedAt: Date) => boolean;
  insertRevocation: (revocation: {
    id: RecordId;
    subscriptionTransactionId: RecordId;
    subscriptionReceiptId: RecordId;
    revokedAt: Date;
  }) => void;
  // 取引の取り消しのうち、戻していないもの
  findUnreversedRevocationIds: (subscriptionTransactionId: RecordId) => RecordId[];
  insertRevocationReversal: (reversal: {
    subscriptionTransactionRevocationId: RecordId;
    subscriptionReceiptId: RecordId;
    reversedAt: Date;
  }) => void;
  // 請求の失敗と、猶予があればその終わりを書く
  insertBillingFailure: (failure: {
    id: RecordId;
    subscriptionTransactionId: RecordId;
    subscriptionReceiptId: RecordId;
    failedAt: Date;
    gracePeriodExpiresAt: Date | undefined;
  }) => void;
  hasNotificationReceipt: (notificationUuid: string) => boolean;
  insertNotificationReceipt: (receipt: {
    subscriptionReceiptId: RecordId;
    subscriptionId: RecordId;
    notificationUuid: string;
    notificationType: string;
    notificationSubtype: string | undefined;
  }) => void;
  insertTransactionReportReceipt: (receipt: {
    subscriptionReceiptId: RecordId;
    subscriptionTransactionId: RecordId;
    reportTrigger: SubscriptionTransactionReportTrigger;
  }) => void;
};
