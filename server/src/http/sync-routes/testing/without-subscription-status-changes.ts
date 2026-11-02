// サブスクリプションの状態の変更を除いた、取りに行った変更。
// 取りに行くと状態の変更が足されうるので、サインインしてから書いた記録の変更だけを比べるテストが使う
export const withoutSubscriptionStatusChanges = <TChange extends { kind: string }>(
  changes: readonly TChange[],
): TChange[] => changes.filter(({ kind }) => kind !== "subscription_status");
