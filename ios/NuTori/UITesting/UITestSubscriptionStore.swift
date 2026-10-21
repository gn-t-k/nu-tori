#if DEBUG
    import Foundation
    import NuToriCore

    /// UI テストは App Store につながない。商品も今使える取引も無く、買うと場面の決めた結果を返す
    nonisolated struct UITestSubscriptionStore: SubscriptionStore {
        let purchaseResult: PurchaseResult

        enum PurchaseResult {
            /// 買う画面を閉じたことにする
            case cancels
            /// 買えたことにする。署名は偽の同期サーバーが確かめない
            case succeeds
        }

        func products(ids: [String]) async throws -> [SubscriptionProduct] {
            []
        }

        /// 課金画面の UI テストの買うところ（`PaywallStorefront.fixed`）が、月額を買ったことにする。本物の StoreKit では `SubscriptionStoreView` が買う
        func purchaseMonthly(appAccountToken: UUID) -> AppStorePurchaseAttempt {
            switch purchaseResult {
            case .cancels:
                .cancelled
            case .succeeds:
                .purchased(
                    AppStoreTransaction(id: 1, signedTransaction: "ui-test-signed-transaction"))
            }
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
