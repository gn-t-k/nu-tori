import {
  appStoreProductPlans,
  type SubscriptionPlan,
  type SubscriptionTransactionFact,
} from "../subscription";

// 取り消されていない取引から出すサブスクリプション。表にもキャッシュの列にも持たず、届いた取引の全部から毎回出す
// （順番が入れ替わって届いた通知でも、同じ答えになるため）
export type Subscription =
  | { type: "none" }
  | {
      type: "subscribed";
      // 期限がいちばん遅い取引の商品
      plan: SubscriptionPlan;
      // 期限がいちばん遅い取引の期限
      periodEndsAt: Date;
      // 取り消されていない取引についた請求の猶予の終わりの最大が、期限より遅いときだけ granted
      billingGrace: { type: "none" } | { type: "granted"; endsAt: Date };
    };

export const computeSubscription = (
  transactions: readonly SubscriptionTransactionFact[],
): Subscription => {
  const valid = transactions.filter(({ revocations }) =>
    revocations.every(({ reversed }) => reversed),
  );
  const latest = valid.reduce<SubscriptionTransactionFact | undefined>(
    (found, candidate) =>
      found === undefined || candidate.expiresAt > found.expiresAt ? candidate : found,
    undefined,
  );
  if (latest === undefined) {
    return { type: "none" };
  }
  const graceEndsAt = valid
    .flatMap(({ gracePeriodExpiresAts }) => gracePeriodExpiresAts)
    .reduce<Date | undefined>(
      (found, candidate) => (found === undefined || candidate > found ? candidate : found),
      undefined,
    );
  return {
    type: "subscribed",
    plan: findPlan(latest.appStoreProductId),
    periodEndsAt: latest.expiresAt,
    billingGrace:
      graceEndsAt !== undefined && graceEndsAt > latest.expiresAt
        ? { type: "granted", endsAt: graceEndsAt }
        : { type: "none" },
  };
};

// 取引を書く口（端末の知らせと App Store のサーバー通知）は知らない商品の取引を書かないので、ここで当たるのは不具合
const findPlan = (appStoreProductId: string): SubscriptionPlan => {
  const plan = appStoreProductPlans[appStoreProductId];
  if (plan === undefined) {
    throw new Error("知らない商品の取引がある");
  }
  return plan;
};
