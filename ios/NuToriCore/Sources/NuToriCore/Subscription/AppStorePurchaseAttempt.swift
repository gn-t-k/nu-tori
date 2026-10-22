/// 買う操作の結果
public enum AppStorePurchaseAttempt: Sendable, Equatable {
    case purchased(AppStoreTransaction)
    /// 買う画面を閉じた
    case cancelled
    /// 承認を待っている（承認と購入のリクエスト）。承認されたら `SubscriptionStore.transactionUpdates()` に流れる
    case pending
}
