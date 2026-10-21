#if DEBUG
    import Foundation
    import NuToriCore

    /// UI テストは App Store につながない。商品も取引も無く、買う画面は閉じたことにする
    nonisolated struct UITestSubscriptionStore: SubscriptionStore {
        func products(ids: [String]) async throws -> [SubscriptionProduct] {
            []
        }

        func purchase(productId: String, appAccountToken: UUID) async throws
            -> AppStorePurchaseAttempt
        {
            .cancelled
        }

        func transactionUpdates() -> AsyncStream<AppStoreTransaction> {
            AsyncStream { $0.finish() }
        }

        func unfinishedTransactions() async -> [AppStoreTransaction] {
            []
        }

        func currentEntitlements() async -> [AppStoreTransaction] {
            []
        }

        func syncWithAppStore() async -> AppStoreSyncResult {
            .synced
        }

        func finish(_ transaction: AppStoreTransaction) async {}

        func willAutoRenew() async -> Bool? {
            nil
        }
    }
#endif
