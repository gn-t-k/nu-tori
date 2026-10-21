import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { AppStoreSubscriptionTransaction } from "./read-app-store-subscription-transaction";
import type { SubscriptionTransactionStore } from "./subscription-transaction-store";

// 届いた取引の写しを書く。サブスクリプションは初めてのときだけ、取引は初めての取引の ID のときだけ書き、
// 同じ取引の ID のあとの写しは書き換えない。受け取りは呼ぶ側が先に書いておく。
// 端末からの知らせと App Store のサーバー通知の両方が、記録の変化を書く入口の run の中で使う
export const writeAppStoreTransaction = (
  store: Pick<
    SubscriptionTransactionStore,
    | "findAppStoreSubscriptionId"
    | "insertAppStoreSubscription"
    | "findTransactionIdByAppStoreTransactionId"
    | "insertAppStoreTransaction"
  >,
  subscriptionReceiptId: RecordId,
  transaction: AppStoreSubscriptionTransaction,
): { subscriptionTransactionId: RecordId; isNewTransaction: boolean } => {
  const writtenTransactionId = store.findTransactionIdByAppStoreTransactionId(
    transaction.appStoreTransactionId,
  );
  if (writtenTransactionId !== undefined) {
    return { subscriptionTransactionId: writtenTransactionId, isNewTransaction: false };
  }
  const key = {
    environment: transaction.environment,
    appStoreOriginalTransactionId: transaction.appStoreOriginalTransactionId,
  };
  const subscriptionId =
    store.findAppStoreSubscriptionId(key) ??
    (() => {
      const id = generateRecordId();
      store.insertAppStoreSubscription({ id, ...key });
      return id;
    })();
  const subscriptionTransactionId = generateRecordId();
  store.insertAppStoreTransaction({
    id: subscriptionTransactionId,
    subscriptionId,
    subscriptionReceiptId,
    transactionReason: transaction.transactionReason,
    purchasedAt: transaction.purchasedAt,
    expiresAt: transaction.expiresAt,
    appStoreTransactionId: transaction.appStoreTransactionId,
    appStoreProductId: transaction.appStoreProductId,
  });
  return { subscriptionTransactionId, isNewTransaction: true };
};
