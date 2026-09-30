/// アカウントの画面から、アカウントと端末の記録に触れる操作
struct AccountActions {
    let signedInAccountId: () async -> String?
    let turnOnUsageData: () async -> Void
    let turnOffUsageData: () async -> Void
    /// 消せなかったときだけ理由を返す。消せたときとセッションが切れていたときは、サインインの画面に置き換わる
    let deleteAccount: () async -> AccountDeletionFailure?
}
