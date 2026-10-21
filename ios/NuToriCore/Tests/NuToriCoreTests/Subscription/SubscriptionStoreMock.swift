import Foundation
import NuToriCore
import Synchronization

/// StoreKit の口の差し替え。終える・突き合わせるを記録する
final class SubscriptionStoreMock: SubscriptionStore, Sendable {
    var finished: [UInt64] { state.withLock { $0.finished } }
    var syncCount: Int { state.withLock { $0.syncCount } }

    static func ok(
        products: [SubscriptionProduct] = [],
        unfinished: [AppStoreTransaction] = [],
        entitlements: [AppStoreTransaction] = [],
        syncResult: AppStoreSyncResult = .synced,
        willAutoRenew: Bool? = nil
    ) -> SubscriptionStoreMock {
        SubscriptionStoreMock(
            products: .success(products), unfinished: unfinished,
            entitlements: entitlements, syncResult: syncResult, willAutoRenew: willAutoRenew)
    }

    /// 商品を読むが投げる。自動更新は、今使えるサブスクリプションの更新の情報だけを端末で読むので、投げずに返せる
    static func error(_ error: any Error, willAutoRenew: Bool? = nil) -> SubscriptionStoreMock {
        SubscriptionStoreMock(
            products: .failure(error), unfinished: [],
            entitlements: [], syncResult: .failed, willAutoRenew: willAutoRenew)
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
        var finished: [UInt64] = []
        var syncCount = 0
    }

    private let productsResult: Result<[SubscriptionProduct], any Error>
    private let unfinished: [AppStoreTransaction]
    private let entitlements: [AppStoreTransaction]
    private let syncResult: AppStoreSyncResult
    private let autoRenew: Bool?
    private let updates = AsyncStream.makeStream(of: AppStoreTransaction.self)
    private let state = Mutex(State())

    private init(
        products: Result<[SubscriptionProduct], any Error>,
        unfinished: [AppStoreTransaction],
        entitlements: [AppStoreTransaction],
        syncResult: AppStoreSyncResult,
        willAutoRenew: Bool?
    ) {
        productsResult = products
        self.unfinished = unfinished
        self.entitlements = entitlements
        self.syncResult = syncResult
        autoRenew = willAutoRenew
    }
}
