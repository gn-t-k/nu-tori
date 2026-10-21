import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { AppStoreSubscriptionTransaction } from "./read-app-store-subscription-transaction";
import type { SubscriptionTransactionStore } from "./subscription-transaction-store";

// 届いた取引の写しを書く。サブスクリプションは初めてのときだけ、取引は初めての取引の ID のときだけ書き、
// 同じ取引の ID のあとの写しは書き換えない。写しに取り消しが載っていれば取り消しを足す。
// ただし同じ取引に同じ取り消しの時刻の取り消しがあれば足さない（#647 の「判定の決まり」）。
// 受け取りは呼ぶ側が先に書いておく。
// 端末からの知らせと App Store のサーバー通知の両方が、記録の変化を書く入口の run の中で使う
export const writeAppStoreTransaction = (
  store: Pick<
    SubscriptionTransactionStore,
    | "findAppStoreSubscriptionId"
    | "insertAppStoreSubscription"
    | "findTransactionIdByAppStoreTransactionId"
    | "insertAppStoreTransaction"
    | "hasRevocationAt"
    | "insertRevocation"
  >,
  subscriptionReceiptId: RecordId,
  transaction: AppStoreSubscriptionTransaction,
): {
  subscriptionId: RecordId;
  subscriptionTransactionId: RecordId;
  // 取引・取り消しを書いたか。書いたら、サブスクリプションの状態が変わりうる
  wroteTransaction: boolean;
  wroteRevocation: boolean;
} => {
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
  const writtenTransactionId = store.findTransactionIdByAppStoreTransactionId(
    transaction.appStoreTransactionId,
  );
  const subscriptionTransactionId =
    writtenTransactionId ??
    (() => {
      const id = generateRecordId();
      store.insertAppStoreTransaction({
        id,
        subscriptionId,
        subscriptionReceiptId,
        transactionReason: transaction.transactionReason,
        purchasedAt: transaction.purchasedAt,
        expiresAt: transaction.expiresAt,
        appStoreTransactionId: transaction.appStoreTransactionId,
        appStoreProductId: transaction.appStoreProductId,
      });
      return id;
    })();
  const { revokedAt } = transaction;
  const isNewRevocation =
    revokedAt !== undefined && !store.hasRevocationAt(subscriptionTransactionId, revokedAt);
  if (isNewRevocation) {
    store.insertRevocation({
      id: generateRecordId(),
      subscriptionTransactionId,
      subscriptionReceiptId,
      revokedAt,
    });
  }
  return {
    subscriptionId,
    subscriptionTransactionId,
    wroteTransaction: writtenTransactionId === undefined,
    wroteRevocation: isNewRevocation,
  };
};
