import Foundation
import NuToriCore
import Synchronization

/// StoreKit の口の差し替え。買う・終える・突き合わせるを記録する
final class SubscriptionStoreMock: SubscriptionStore, Sendable {
    var purchases: [Purchase] { state.withLock { $0.purchases } }
    var finished: [UInt64] { state.withLock { $0.finished } }
    var syncCount: Int { state.withLock { $0.syncCount } }

    struct Purchase: Equatable {
        let productId: String
        let appAccountToken: UUID
    }

    static func ok(
        products: [SubscriptionProduct] = [],
        purchase: AppStorePurchaseAttempt = .cancelled,
        unfinished: [AppStoreTransaction] = [],
        entitlements: [AppStoreTransaction] = [],
        syncResult: AppStoreSyncResult = .synced,
        willAutoRenew: Bool? = nil
    ) -> SubscriptionStoreMock {
        SubscriptionStoreMock(
            products: .success(products), purchase: .success(purchase), unfinished: unfinished,
            entitlements: entitlements, syncResult: syncResult, willAutoRenew: willAutoRenew)
    }

    /// 商品を読む・買うが投げる
    static func error(_ error: any Error) -> SubscriptionStoreMock {
        SubscriptionStoreMock(
            products: .failure(error), purchase: .failure(error), unfinished: [],
            entitlements: [], syncResult: .failed, willAutoRenew: nil)
    }

    /// `Transaction.updates` に取引を流す
    func yieldUpdate(_ transaction: AppStoreTransaction) {
        updates.continuation.yield(transaction)
    }

    func endUpdates() {
        updates.continuation.finish()
    }

    func products(ids: [String]) async throws -> [SubscriptionProduct] {
        try productsResult.get().filter { ids.contains($0.id) }
    }

    func purchase(productId: String, appAccountToken: UUID) async throws
        -> AppStorePurchaseAttempt
    {
        state.withLock {
            $0.purchases.append(Purchase(productId: productId, appAccountToken: appAccountToken))
        }
        return try purchaseResult.get()
    }

    func transactionUpdates() -> AsyncStream<AppStoreTransaction> {
        updates.stream
    }

    /// 終えた取引は除く
    func unfinishedTransactions() async -> [AppStoreTransaction] {
        let finished = self.finished
        return unfinished.filter { !finished.contains($0.id) }
    }

    func currentEntitlements() async -> [AppStoreTransaction] {
        entitlements
    }

    func syncWithAppStore() async -> AppStoreSyncResult {
        state.withLock { $0.syncCount += 1 }
        return syncResult
    }

    func finish(_ transaction: AppStoreTransaction) async {
        state.withLock { $0.finished.append(transaction.id) }
    }

    func willAutoRenew() async -> Bool? {
        autoRenew
    }

    private struct State {
        var purchases: [Purchase] = []
        var finished: [UInt64] = []
        var syncCount = 0
    }

    private let productsResult: Result<[SubscriptionProduct], any Error>
    private let purchaseResult: Result<AppStorePurchaseAttempt, any Error>
    private let unfinished: [AppStoreTransaction]
    private let entitlements: [AppStoreTransaction]
    private let syncResult: AppStoreSyncResult
    private let autoRenew: Bool?
    private let updates = AsyncStream.makeStream(of: AppStoreTransaction.self)
    private let state = Mutex(State())

    private init(
        products: Result<[SubscriptionProduct], any Error>,
        purchase: Result<AppStorePurchaseAttempt, any Error>,
        unfinished: [AppStoreTransaction],
        entitlements: [AppStoreTransaction],
        syncResult: AppStoreSyncResult,
        willAutoRenew: Bool?
    ) {
        productsResult = products
        purchaseResult = purchase
        self.unfinished = unfinished
        self.entitlements = entitlements
        self.syncResult = syncResult
        autoRenew = willAutoRenew
    }
}
