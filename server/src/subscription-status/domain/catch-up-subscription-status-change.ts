import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import { computeSubscriptionStatus } from "./compute-subscription-status";

// サブスクリプションの状態の変更を帳簿に足すのは、ここだけにする（#881）。取りに来た要求が、変更を返す前に呼ぶ。
// 今の状態が、最後に帳簿に載せた状態と違えば、変更を足し、載せた状態を書き足す。
// 状態は事実（取引・取り消し・猶予、無料体験なし、D1 のテストユーザーの旗、課金を入れた日）が変わったときしか変わらず、時刻が過ぎただけでは変わらない（端末が日付と今日を比べて描く）ので、取りに来たときに比べれば、どの事実の変化も届く。
// 最初のサインインがまだ無ければ何もしない
export const catchUpSubscriptionStatusChange = (
  writeRecordChanges: RecordChangeWriter,
  stores: Pick<RecordKindStores, "subscriptionStatus">,
  now: Date,
): void => {
  const store = stores.subscriptionStatus;
  const facts = store.findFacts();
  if (facts === undefined) {
    return;
  }
  // 状態は同じ事実からいつも同じ形で組むので、JSON の文字列のまま比べる
  const status = JSON.stringify(computeSubscriptionStatus(facts));
  if (store.findLedgeredStatus() === status) {
    return;
  }
  writeRecordChanges(({ addChange }) => {
    store.insertLedgeredStatus({ status, ledgeredAt: now });
    addChange({ recordType: "subscription_status", recordId: facts.firstSignInId });
  });
};
