import Foundation
import NuToriCore
import StoreKit

/// StoreKit 2 の adapter。署名はサーバーが確かめるので、確かめられなかった取引もそのまま渡す
nonisolated struct StoreKitSubscriptionStore: SubscriptionStore {
    func products(ids: [String]) async throws -> [SubscriptionProduct] {
        try await Product.products(for: ids).compactMap { product in
            SubscriptionProduct.ids[product.id].map {
                SubscriptionProduct(id: product.id, plan: $0, displayPrice: product.displayPrice)
            }
        }
    }

    func purchase(productId: String, appAccountToken: UUID) async throws
        -> AppStorePurchaseAttempt
    {
        guard let product = try await Product.products(for: [productId]).first else {
            throw ProductNotFoundError()
        }
        return AppStorePurchaseAttempt(
            try await product.purchase(options: [.appAccountToken(appAccountToken)]))
    }

    func transactionUpdates() -> AsyncStream<AppStoreTransaction> {
        AsyncStream { continuation in
            let task = Task {
                for await verification in Transaction.updates {
                    continuation.yield(AppStoreTransaction(verification))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func unfinishedTransactions() async -> [AppStoreTransaction] {
        await Transaction.unfinished.reduce(into: []) { $0.append(AppStoreTransaction($1)) }
    }

    func currentEntitlements() async -> [AppStoreTransaction] {
        await Transaction.currentEntitlements.reduce(into: []) {
            $0.append(AppStoreTransaction($1))
        }
    }

    func syncWithAppStore() async -> AppStoreSyncResult {
        do {
            try await AppStore.sync()
            return .synced
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            return .failed
        }
    }

    /// 取引の値は持ち回らないので、終えていない取引から同じ ID のものを探して終える。見つからなければ終えてある
    func finish(_ transaction: AppStoreTransaction) async {
        for await verification in Transaction.unfinished
        where verification.unsafePayloadValue.id == transaction.id {
            await verification.unsafePayloadValue.finish()
        }
    }

    func willAutoRenew() async -> Bool? {
        for await verification in Transaction.currentEntitlements {
            let transaction = verification.unsafePayloadValue
            guard transaction.productType == .autoRenewable,
                let status = await transaction.subscriptionStatus,
                case .verified(let renewalInfo) = status.renewalInfo
            else { continue }
            return renewalInfo.willAutoRenew
        }
        return nil
    }

    private struct ProductNotFoundError: Error {}
}

nonisolated extension AppStorePurchaseAttempt {
    /// 課金画面の `SubscriptionStoreView` で買えた結果も、これで口の形にする
    init(_ result: Product.PurchaseResult) {
        switch result {
        case .success(let verification):
            self = .purchased(AppStoreTransaction(verification))
        case .userCancelled:
            self = .cancelled
        case .pending:
            self = .pending
        @unknown default:
            self = .cancelled
        }
    }
}

nonisolated extension AppStoreTransaction {
    fileprivate init(_ verification: VerificationResult<Transaction>) {
        self.init(
            id: verification.unsafePayloadValue.id,
            signedTransaction: verification.jwsRepresentation)
    }
}
