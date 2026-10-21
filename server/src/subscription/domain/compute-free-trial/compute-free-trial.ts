import { addDays } from "../../../domain/add-days";

// 無料体験。作り直したアカウントには無い。最後の日（YYYY-MM-DD）の終わりまでが無料体験中
export type FreeTrial =
  | { type: "available"; lastDay: string }
  | { type: "used_by_earlier_account" };

// 最後の日は、アカウントを作った日と課金を入れた日の遅いほうから数えた30日目（課金を入れる前からのアカウントが、入れた日に使えなくならないため）
export const computeFreeTrial = (account: {
  // first_sign_ins.started_on
  startedOn: string;
  // 課金を入れた日（環境ごとの設定値）
  billingStartedOn: string;
  // free_trial_exclusions に行があるか
  isExcludedByEarlierAccount: boolean;
}): FreeTrial => {
  if (account.isExcludedByEarlierAccount) {
    return { type: "used_by_earlier_account" };
  }
  const firstDay =
    account.startedOn > account.billingStartedOn ? account.startedOn : account.billingStartedOn;
  return { type: "available", lastDay: addDays(firstDay, freeTrialDays - 1) };
};

const freeTrialDays = 30;
