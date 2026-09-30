/// アカウントの画面から、アカウントと端末の記録に触れる操作
struct AccountActions {
    let signedInAccountId: () async -> String?
    let setSendsUsageData: (Bool) async -> Void
    /// 消せたときは、サインインの画面に置き換えて nil を返す
    let deleteAccount: () async -> AccountDeletionFailure?
}
