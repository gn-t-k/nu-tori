import type { RecordKindStores } from "../../domain/record-kind-stores";
import { findSubscriptionCheck } from "./find-subscription-check";
import { findSubscriptionTimeZone } from "./find-subscription-time-zone";

// 課金の仕事（アラーム）の時機。最初のサインインがまだ無ければ undefined。
// 保留した推定があるのにテストユーザーなら、切れていたあいだに旗を立てたので、今すぐ動いて再開する
// （旗の変化を Durable Object は知らず、買ったときのように再開する事実の書き込みが無いため。再開すると保留は無くなる）
export const readSubscriptionCheck = (
  stores: Pick<
    RecordKindStores,
    "subscriptionStatus" | "latestTimeZone" | "firstSignIn" | "estimationSchedule"
  >,
  now: Date,
): { nextAt: Date | undefined; isDue: boolean } | undefined => {
  const facts = stores.subscriptionStatus.findFacts();
  if (facts === undefined) {
    return undefined;
  }
  if (facts.isTestUser && stores.estimationSchedule.findHeldTargets().length > 0) {
    return { nextAt: now, isDue: true };
  }
  return findSubscriptionCheck(facts, findSubscriptionTimeZone(stores), now);
};
