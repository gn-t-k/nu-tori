import type { SubscriptionTransactionFact } from "../../subscription/domain/subscription";

// サブスクリプションの状態を計算する元の事実を読む置き場。DO の表のほかに、D1 のテストユーザーの旗と、環境ごとの課金を入れた日も渡す
export type SubscriptionStatusStore = {
  // 最初のサインインがまだ無ければ undefined
  findFacts: () => SubscriptionStatusFacts | undefined;
};

export type SubscriptionStatusFacts = {
  firstSignInId: string;
  // アカウントを作った日（YYYY-MM-DD）
  startedOn: string;
  // 課金を入れた日（YYYY-MM-DD）
  billingStartedOn: string;
  isTestUser: boolean;
  isExcludedByEarlierAccount: boolean;
  transactions: SubscriptionTransactionFact[];
};
