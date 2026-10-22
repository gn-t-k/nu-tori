import type { RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import { findSubscriptionCheck } from "./find-subscription-check";
import { findSubscriptionTimeZone } from "./find-subscription-time-zone";

// 課金の仕事（アラーム）の時機。最初のサインインがまだ無ければ undefined。
// 帳簿に状態の記録の変更がまだ1つも無い（課金を入れる前からの）アカウントは、今すぐ動いて変更を足す。
// 保留した推定があるのにテストユーザーなら、切れていたあいだに旗を立てたので、今すぐ動いて変更を足し、再開する
// （区切りの時刻が無い切れたアカウントにも届けるため。再開すると保留は無くなる）
export const readSubscriptionCheck = (
  stores: Pick<
    RecordKindStores,
    "subscriptionStatus" | "latestTimeZone" | "firstSignIn" | "estimationSchedule"
  >,
  now: Date,
): { firstSignInId: RecordId; nextAt: Date | undefined; isDue: boolean } | undefined => {
  const facts = stores.subscriptionStatus.findFacts();
  if (facts === undefined) {
    return undefined;
  }
  // 帳簿の変更の並びは種類で引く索引が無い。変更を1つ足したアカウントは、最初のサインインの変更が並びの先頭近くにあり、すぐ見つかる
  if (
    !stores.subscriptionStatus.hasRecordedChange() ||
    (facts.isTestUser && stores.estimationSchedule.findHeldTargets().length > 0)
  ) {
    return { firstSignInId: facts.firstSignInId, nextAt: now, isDue: true };
  }
  return {
    firstSignInId: facts.firstSignInId,
    ...findSubscriptionCheck(facts, findSubscriptionTimeZone(stores), now),
  };
};
