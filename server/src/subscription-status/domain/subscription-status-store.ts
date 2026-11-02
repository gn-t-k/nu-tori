import type { RecordId } from "../../domain/record-id";
import type { SubscriptionTransactionFact } from "../../subscription/domain/subscription-transaction-fact";

// サブスクリプションの状態を計算する元の事実を読む置き場。DO の表のほかに、D1 のテストユーザーの旗と、環境ごとの課金を入れた日も渡す
export type SubscriptionStatusStore = {
  // 最初のサインインがまだ無ければ undefined
  findFacts: () => SubscriptionStatusFacts | undefined;
  // 帳簿に状態の変更を最後に載せたときの状態（JSON の文字列）。まだ載せていなければ undefined
  findLedgeredStatus: () => string | undefined;
  // 帳簿に状態の変更を載せたときの状態を書き足す。記録の変化を書く入口の run の中で呼ぶ
  insertLedgeredStatus: (ledgered: { status: string; ledgeredAt: Date }) => void;
};

export type SubscriptionStatusFacts = {
  firstSignInId: RecordId;
  // アカウントを作った日（YYYY-MM-DD）
  startedOn: string;
  // 課金を入れた日（YYYY-MM-DD）
  billingStartedOn: string;
  isTestUser: boolean;
  isExcludedByEarlierAccount: boolean;
  transactions: SubscriptionTransactionFact[];
};
