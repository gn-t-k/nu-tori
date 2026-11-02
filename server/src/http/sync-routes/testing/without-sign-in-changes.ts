// サインインのあと最初に取りに行ったときに足すサブスクリプションの状態の変更（#881）を除いた、取りに行った変更。
// サインインしてから書いた記録の変更だけを比べるテストが使う
export const withoutSignInChanges = <TChange extends { kind: string }>(
  changes: readonly TChange[],
): TChange[] => changes.filter(({ kind }) => kind !== "subscription_status");
