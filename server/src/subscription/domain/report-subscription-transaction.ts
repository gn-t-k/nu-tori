import { match } from "ts-pattern";
import { createDishEstimationStatusKind } from "../../dish-estimation-status/domain/create-dish-estimation-status-kind";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { UsageEvent } from "../../domain/usage-event";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { EstimationTarget } from "../../estimation/domain/estimation-target";
import { createMealEstimationStatusKind } from "../../meal-estimation-status/domain/create-meal-estimation-status-kind";
import { createSubscriptionStatusKind } from "../../subscription-status/domain/create-subscription-status-kind";
import type { AppStoreSubscriptionTransaction } from "./read-app-store-subscription-transaction";
import type { SubscriptionTransactionReportTrigger } from "./subscription-transaction-fact";
import type { SubscriptionTransactionStore } from "./subscription-transaction-store";
import { writeReceivedSubscriptionFacts } from "./write-received-subscription-facts";

export type SubscriptionTransactionReport = {
  // 端末が振った要求の ID。受け取りの ID にし、冪等の鍵にする
  requestId: RecordId;
  trigger: SubscriptionTransactionReportTrigger;
  transaction: AppStoreSubscriptionTransaction;
};

// 応答に載せる記録。同期の変更と同じ順（サブスクリプションの状態、再開した推定の状態）
export type ReportedRecord = {
  recordType: RecordType;
  recordId: RecordId;
  current: CurrentRecord<unknown>;
};

// 端末からの取引の知らせを、記録の変化を書く入口の1つのトランザクションで書く（案内は呼ぶ前に D1 で決めておく）。
// 取引か取り消しを書いたら、サブスクリプションの状態の変更を足し、保留した推定を再開する。
// 同じ要求の ID の再送は、書かずに今の状態を返す
export const reportSubscriptionTransaction = (
  writeRecordChanges: RecordChangeWriter,
  stores: {
    subscriptionTransaction: SubscriptionTransactionStore;
    records: Pick<
      RecordKindStores,
      | "estimationSchedule"
      | "latestTimeZone"
      | "meal"
      | "mealEstimationStatus"
      | "dish"
      | "dishEstimationStatus"
      | "subscriptionStatus"
      | "firstSignIn"
    >;
  },
  report: SubscriptionTransactionReport,
  now: Date,
): { records: ReportedRecord[]; usageEvents: UsageEvent[] } => {
  const { subscriptionTransaction: store, records } = stores;
  const firstSignInId = records.subscriptionStatus.findFacts()?.firstSignInId;
  if (firstSignInId === undefined) {
    throw new Error("最初のサインインの無いアカウントに取引が届いた");
  }
  const written = writeRecordChanges(
    (writes): { resumedTargets: EstimationTarget[]; usageEvents: UsageEvent[] } => {
      if (store.hasReceipt(report.requestId)) {
        return { resumedTargets: [], usageEvents: [] };
      }
      return writeReceivedSubscriptionFacts(
        stores,
        writes,
        { receiptId: report.requestId, firstSignInId, transaction: report.transaction, now },
        ({ subscriptionTransactionId }) => {
          store.insertTransactionReportReceipt({
            subscriptionReceiptId: report.requestId,
            subscriptionTransactionId,
            reportTrigger: report.trigger,
          });
          return false;
        },
      );
    },
  );
  return {
    usageEvents: written.usageEvents,
    records: [
      {
        recordType: "subscription_status",
        recordId: firstSignInId,
        current: createSubscriptionStatusKind(records.subscriptionStatus).readCurrent(
          firstSignInId,
        ),
      },
      ...written.resumedTargets.map((target) => readResumedStatus(records, target, now)),
    ],
  };
};

const readResumedStatus = (
  records: Pick<
    RecordKindStores,
    "meal" | "mealEstimationStatus" | "dish" | "dishEstimationStatus"
  >,
  target: EstimationTarget,
  now: Date,
): ReportedRecord =>
  match(target)
    .returnType<ReportedRecord>()
    .with({ type: "meal" }, ({ mealId }) => ({
      recordType: "meal_estimation_status",
      recordId: mealId,
      current: createMealEstimationStatusKind(
        records.meal,
        records.mealEstimationStatus,
      ).readCurrent(mealId),
    }))
    .with({ type: "dish" }, ({ dishId }) => ({
      recordType: "dish_estimation_status",
      recordId: dishId,
      current: createDishEstimationStatusKind(
        records.dish,
        records.dishEstimationStatus,
        now,
      ).readCurrent(dishId),
    }))
    .exhaustive();
