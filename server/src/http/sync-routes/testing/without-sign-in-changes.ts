// 最初のサインインが足すサブスクリプションの状態の変更を除いた、取りに行った変更。
// サインインしてから書いた記録の変更だけを比べるテストが使う
export const withoutSignInChanges = <TChange extends { kind: string }>(
  changes: readonly TChange[],
): TChange[] => changes.filter(({ kind }) => kind !== "subscription_status");
