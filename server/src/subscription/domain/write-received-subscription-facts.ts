import type { RecordChangeWrites } from "../../domain/record-change-writes";
import type { RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { UsageEvent } from "../../domain/usage-event";
import type { EstimationTarget } from "../../estimation/domain/estimation-target";
import { resumeHeldEstimations } from "../../estimation/domain/resume-held-estimations";
import { createWrittenFactUsageEvents } from "./create-written-fact-usage-events";
import type { AppStoreSubscriptionTransaction } from "./read-app-store-subscription-transaction";
import type { SubscriptionTransactionStore } from "./subscription-transaction-store";
import { writeAppStoreTransaction } from "./write-app-store-transaction";

// 端末の取引の知らせと App Store のサーバー通知が、記録の変化を書く入口の run の中で事実を書く流れ。
// 受け取り、運んだ取引の写し、出どころの事実（writeSourceFacts。状態が変わりうる事実を書いたら true を返す）の順に書く。
// 取引・取り消し・出どころの事実のどれかを書いたら、サブスクリプションの状態の変更を足し、保留した推定を再開して、出来事を作る
export const writeReceivedSubscriptionFacts = (
  stores: {
    subscriptionTransaction: SubscriptionTransactionStore;
    records: Pick<
      RecordKindStores,
      "estimationSchedule" | "latestTimeZone" | "meal" | "subscriptionStatus" | "firstSignIn"
    >;
  },
  { addChange, estimation }: Pick<RecordChangeWrites, "addChange" | "estimation">,
  received: {
    receiptId: RecordId;
    firstSignInId: RecordId;
    transaction: AppStoreSubscriptionTransaction;
    now: Date;
  },
  writeSourceFacts: (written: {
    subscriptionId: RecordId;
    subscriptionTransactionId: RecordId;
  }) => boolean,
): { resumedTargets: EstimationTarget[]; usageEvents: UsageEvent[] } => {
  const { subscriptionTransaction: store, records } = stores;
  const { receiptId, firstSignInId, transaction, now } = received;
  store.insertReceipt({ id: receiptId, receivedAt: now });
  const { subscriptionId, subscriptionTransactionId, wroteTransaction, wroteRevocation } =
    writeAppStoreTransaction(store, receiptId, transaction);
  const wroteSourceFact = writeSourceFacts({ subscriptionId, subscriptionTransactionId });
  if (!wroteTransaction && !wroteRevocation && !wroteSourceFact) {
    return { resumedTargets: [], usageEvents: [] };
  }
  addChange({ recordType: "subscription_status", recordId: firstSignInId });
  return {
    // 使えるかを書いた事実で判定するので、事実の行のあとに呼ぶ
    resumedTargets: resumeHeldEstimations(records, estimation, now),
    usageEvents: createWrittenFactUsageEvents(
      records,
      transaction,
      { wroteTransaction, wroteRevocation },
      now,
    ),
  };
};
