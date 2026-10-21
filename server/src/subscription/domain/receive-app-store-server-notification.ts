import { match, P } from "ts-pattern";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import { resumeHeldEstimations } from "../../estimation/domain/resume-held-estimations";
import type { AppStoreSubscriptionTransaction } from "./read-app-store-subscription-transaction";
import type { SubscriptionTransactionStore } from "./subscription-transaction-store";
import { writeAppStoreTransaction } from "./write-app-store-transaction";

// 署名を確かめ、案内を引いた App Store のサーバー通知のうち、書くのに使う値
export type AppStoreServerNotificationReceipt = {
  notificationUuid: string;
  notificationType: string;
  notificationSubtype: string | undefined;
  // 通知の signedDate。請求の失敗の時刻と、取り消しの戻しの時刻にする
  signedAt: Date;
  transaction: AppStoreSubscriptionTransaction;
  // 更新の情報の gracePeriodExpiresDate
  gracePeriodExpiresAt: Date | undefined;
};

// written: 受け取りを書いた。duplicate: 同じ notificationUUID を受け取り済みで、何も書かない。
// awaiting_revocation: 取り消しの戻しが、戻す取り消しより先に届いた。何も書かず、Apple の送り直しに任せる
export type AppStoreServerNotificationResult = "written" | "duplicate" | "awaiting_revocation";

// App Store のサーバー通知を、記録の変化を書く入口の1つのトランザクションで書く（#647 の「App Store のサーバー通知を受ける」）。
// どの種類も、運んだ取引の写しを端末の知らせと同じ決まりで書き（初めての取引の ID なら取引、載っていれば取り消し）、
// 種類ごとの事実を足す。受け取りの行が運んだサブスクリプションを指すので、受け取りだけの種類でも、
// サブスクリプションがまだ無ければ運んだ取引で書く。事実を書いたら、サブスクリプションの状態の変更を足し、保留した推定を再開する
export const receiveAppStoreServerNotification = (
  writeRecordChanges: RecordChangeWriter,
  stores: {
    subscriptionTransaction: SubscriptionTransactionStore;
    records: Pick<
      RecordKindStores,
      "estimationSchedule" | "latestTimeZone" | "meal" | "subscriptionStatus"
    >;
  },
  notification: AppStoreServerNotificationReceipt,
  now: Date,
): AppStoreServerNotificationResult => {
  const { subscriptionTransaction: store, records } = stores;
  const firstSignInId = records.subscriptionStatus.findFacts()?.firstSignInId;
  if (firstSignInId === undefined) {
    throw new Error("最初のサインインの無いアカウントに App Store のサーバー通知が届いた");
  }
  return writeRecordChanges(({ addChange, estimationAt }): AppStoreServerNotificationResult => {
    if (store.hasNotificationReceipt(notification.notificationUuid)) {
      return "duplicate";
    }
    const reversedRevocationIds = match(notification.notificationType)
      .with("REFUND_REVERSED", () => findUnreversedRevocationIds(store, notification.transaction))
      .otherwise(() => undefined);
    if (reversedRevocationIds?.length === 0) {
      return "awaiting_revocation";
    }
    const receiptId = generateRecordId();
    store.insertReceipt({ id: receiptId, receivedAt: now });
    const { subscriptionId, subscriptionTransactionId, wroteFact } = writeAppStoreTransaction(
      store,
      receiptId,
      notification.transaction,
    );
    store.insertNotificationReceipt({
      subscriptionReceiptId: receiptId,
      subscriptionId,
      notificationUuid: notification.notificationUuid,
      notificationType: notification.notificationType,
      notificationSubtype: notification.notificationSubtype,
    });
    const wroteKindFact = match(notification)
      .with({ notificationType: "DID_FAIL_TO_RENEW" }, ({ notificationSubtype }) => {
        // 運んだ取引は、更新に失敗した期間の前の期間の取引
        store.insertBillingFailure({
          id: generateRecordId(),
          subscriptionTransactionId,
          subscriptionReceiptId: receiptId,
          failedAt: notification.signedAt,
          gracePeriodExpiresAt: match(notificationSubtype)
            .with("GRACE_PERIOD", () => notification.gracePeriodExpiresAt)
            .otherwise(() => undefined),
        });
        return true;
      })
      .with({ notificationType: "REFUND_REVERSED" }, () => {
        for (const revocationId of reversedRevocationIds ?? []) {
          store.insertRevocationReversal({
            subscriptionTransactionRevocationId: revocationId,
            subscriptionReceiptId: receiptId,
            reversedAt: notification.signedAt,
          });
        }
        return true;
      })
      // 取引と取り消し（REFUND・REVOKE の取引の revocationDate）は、運んだ取引の写しを書くときに書いた。
      // EXPIRED・GRACE_PERIOD_EXPIRED などは受け取りだけ（終わりは事実に持たず導出する）
      .with({ notificationType: P.string }, () => false)
      .exhaustive();
    if (!wroteFact && !wroteKindFact) {
      return "written";
    }
    addChange({ recordType: "subscription_status", recordId: firstSignInId });
    // 使えるかを書いた事実で判定するので、事実の行のあとに呼ぶ
    resumeHeldEstimations(records, estimationAt(now), now);
    return "written";
  });
};

// 書いた取引の、戻していない取り消し。取引がまだ無ければ空
const findUnreversedRevocationIds = (
  store: Pick<
    SubscriptionTransactionStore,
    "findTransactionIdByAppStoreTransactionId" | "findUnreversedRevocationIds"
  >,
  transaction: AppStoreSubscriptionTransaction,
): RecordId[] => {
  const subscriptionTransactionId = store.findTransactionIdByAppStoreTransactionId(
    transaction.appStoreTransactionId,
  );
  return subscriptionTransactionId === undefined
    ? []
    : store.findUnreversedRevocationIds(subscriptionTransactionId);
};
