import Foundation

/// StoreKit の口。アプリは StoreKit 2 の adapter を渡し、テストと UI テストは偽物を渡す。
/// 課金画面の `SubscriptionStoreView` はこの口の外で、買えた取引だけを `SubscriptionPurchases.reportPurchase(_:)` に渡す
public protocol SubscriptionStore: Sendable {
    /// App Store にある商品だけを返す
    func products(ids: [String]) async throws -> [SubscriptionProduct]

    /// `Transaction.updates`。ほかの端末で買った・更新した取引と、起動した直後の終えていない取引が流れる
    func transactionUpdates() -> AsyncStream<AppStoreTransaction>

    /// まだ終えていない取引（`Transaction.unfinished`）
    func unfinishedTransactions() async -> [AppStoreTransaction]

    /// 今使える取引（`Transaction.currentEntitlements`）
    func currentEntitlements() async -> [AppStoreTransaction]

    /// App Store と取引を突き合わせる（`AppStore.sync()`）。Apple アカウントへのサインインを求めることがある
    func syncWithAppStore() async -> AppStoreSyncResult

    /// 取引を終える。終えていない取引は、次に起動したときにもう一度流れる
    func finish(_ transaction: AppStoreTransaction) async

    /// 今使えるサブスクリプションの更新の情報の自動更新
    func autoRenewal() async -> SubscriptionPurchases.AutoRenewal
}

public enum AppStoreSyncResult: Sendable {
    case synced
    /// Apple アカウントへのサインインを閉じた
    case cancelled
    /// 突き合わせられなかった。StoreKit が包んだ原因（つながらないなど）があれば、包みを解いた原因
    case failed(any Error)
}
