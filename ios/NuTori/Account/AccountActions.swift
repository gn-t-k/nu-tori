import NuToriCore

/// アカウントの画面から、アカウントと端末の記録と通知の許可に触れる操作
struct AccountActions {
    let signedInAccountId: () async -> String?
    let turnOnUsageData: () async -> Void
    let turnOffUsageData: () async -> Void
    /// 消せなかったときだけ理由を返す。消せたときとセッションが切れていたときは、サインインの画面に置き換わる
    let deleteAccount: () async -> AccountDeletionFailure?
    /// このアプリの通知の許可を読む。設定から戻るたびに読み直す
    let notificationPermission: () async -> NotificationPermission
    /// 通知の行から iPhone の設定を開いた
    let openedNotificationSettings: () async -> Void
    /// サブスクリプション中で自動更新がオンのときだけ、確かめの前に出す退会の案内を返す
    let accountDeletionGuide: () async -> AccountDeletionGuide?
    /// 解約の画面から戻ったときに、退会の案内の自動更新を読み直す
    let rereadAccountDeletionGuide: (AccountDeletionGuide) async -> AccountDeletionGuide
    let openedAccountDeletionGuide: () async -> Void
    /// 退会の案内から解約の画面を開いた
    let openedManageSubscriptions: () async -> Void
}
