import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { UsageEvent } from "../../domain/usage-event";
import { resumeHeldEstimations } from "../../estimation/domain/resume-held-estimations";
import { findDeadlineExpiredEvent } from "./find-deadline-expired-event";
import { findSubscriptionTimeZone } from "./find-subscription-time-zone";
import { readSubscriptionCheck } from "./read-subscription-check";
import { readSubscriptionFacts } from "./read-subscription-facts";

// 課金の仕事（アラーム）の入口。無料体験とサブスクリプションの区切りの時刻に、サブスクリプションの状態の変更を足し、
// 使えるようになっていれば保留した推定を再開する（テストユーザーの旗の変化は、Durable Object が知らないので、これで届く）。
// 区切りの時刻でなければ何もしない。送る出来事（切れた）を返す
export const advanceSubscriptionCheck = (
  writeRecordChanges: RecordChangeWriter,
  stores: Pick<
    RecordKindStores,
    "subscriptionStatus" | "latestTimeZone" | "firstSignIn" | "estimationSchedule" | "meal"
  >,
  now: Date,
): UsageEvent[] => {
  const check = readSubscriptionCheck(stores, now);
  if (check?.isDue !== true) {
    return [];
  }
  const expiredEvent = writeRecordChanges(({ addChange, estimationAt }) => {
    addChange({ recordType: "subscription_status", recordId: check.firstSignInId });
    resumeHeldEstimations(stores, estimationAt(now), now);
    return findDeadlineExpiredEvent(
      readSubscriptionFacts(stores.subscriptionStatus),
      findSubscriptionTimeZone(stores),
      now,
    );
  });
  return expiredEvent === undefined ? [] : [expiredEvent];
};
