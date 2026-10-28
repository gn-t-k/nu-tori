public import Foundation
public import NuToriAPI

/// サブスクリプションを買う・復元する・取引をサーバーに知らせる。取引は、サーバーの応答を受け取ってから終える
public actor SubscriptionPurchases {
    /// - Parameter applyReportedChanges: 取引を知らせた応答の記録を、取りに行った変更と同じ道でキャッシュに当てる
    public init(
        store: any SubscriptionStore,
        client: NuToriAPIClient,
        applyReportedChanges: @escaping @Sendable ([SyncChange]) async throws -> Void,
        errorReporting: any ErrorReportingSession,
        newRequestId: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.store = store
        self.client = client
        self.applyReportedChanges = applyReportedChanges
        self.errorReporting = errorReporting
        self.newRequestId = newRequestId
    }

    /// 買うときに App Store に渡す購入者のトークン。課金画面の `SubscriptionStoreView` は、これを購入の選択肢で渡す
    public func appAccountToken() async -> AppAccountTokenOutcome {
        do {
            guard case .issued(let token) = try await client.issueAppAccountToken() else {
                return .unavailable(.retryLater)
            }
            return .issued(token)
        } catch {
            return .unavailable(RequestFailureReason(error))
        }
    }

    /// 買えた取引を知らせる。課金画面の `SubscriptionStoreView` で買えたときも、ここに渡す
    public func reportPurchase(_ transaction: AppStoreTransaction) async -> PurchaseOutcome {
        switch await report(transaction, trigger: .purchase) {
        case .linked: .linked
        case .ownedByOtherAccount: .ownedByOtherAccount
        case .rejected: .rejected
        case .notReported(let reason): .notLinkedYet(reason)
        }
    }

    /// 開いたとき（前面に来たとき）。終えていない取引を知らせ直す。知らせられなかった取引は、次に開いたときにまた知らせる
    public func reportUnfinishedTransactions() async {
        for transaction in await store.unfinishedTransactions() {
            _ = await report(transaction, trigger: .transactionUpdates)
        }
    }

    /// 起動してから、`Transaction.updates` に流れる取引を知らせ続ける。ほかの端末で買った取引、更新、承認された購入が流れる
    public func watchTransactionUpdates() async {
        for await transaction in store.transactionUpdates() {
            _ = await report(transaction, trigger: .transactionUpdates)
        }
    }

    /// 「購入を復元」。App Store と突き合わせてから、今使える取引をすべて知らせる。
    /// 突き合わせられなくても、端末にある今使える取引を知らせる。StoreKit は今使える取引を自動で最新に保ち、
    /// 新しい端末でも最初の起動から読める。TestFlight では、パスワードを入れたあとに `AppStore.sync()` が投げることがある（#829）
    public func restore() async -> RestoreOutcome {
        var syncFailure: (any Error)?
        switch await store.syncWithAppStore() {
        case .synced: break
        case .cancelled: return .cancelled
        case .failed(let error):
            await errorReporting.report(error, as: .appStoreSync)
            syncFailure = error
        }
        var outcomes: [ReportOutcome] = []
        for transaction in await store.currentEntitlements() {
            outcomes.append(await report(transaction, trigger: .restore))
        }
        // 突き合わせられなかったので、復元するものが無いとは言い切れない
        if outcomes.isEmpty, let syncFailure {
            return .failed(RequestFailureReason(syncFailure))
        }
        return RestoreOutcome(outcomes)
    }

    /// 今使えるサブスクリプションの自動更新。アカウントの行と退会の案内で「解約しました」を出すかに使う
    public func autoRenewal() async -> AutoRenewal {
        await store.autoRenewal()
    }

    /// 月額・年額の商品。月額、年額の順
    public func products() async throws -> [SubscriptionProduct] {
        try await store.products(ids: Array(SubscriptionProduct.ids.keys))
            .sorted { $0.plan == .monthly && $1.plan == .yearly }
    }

    public enum PurchaseOutcome: Sendable, Equatable {
        /// このアカウントのサブスクリプションになった
        case linked
        /// この Apple アカウントのサブスクリプションは、ほかの nu-tori のアカウントのもの
        case ownedByOtherAccount
        /// 買えたが、まだサーバーに知らせられていない。取引は終えずに残し、次に開いたときに知らせ直す
        case notLinkedYet(RequestFailureReason)
        /// サーバーが取引を受け付けなかった。不具合のときだけ起きる
        case rejected
    }

    public enum AppAccountTokenOutcome: Sendable, Equatable {
        case issued(UUID)
        /// 受け取れなかった。受け取れるまで買えない
        case unavailable(RequestFailureReason)
    }

    public enum RestoreOutcome: Sendable, Equatable {
        /// このアカウントのサブスクリプションになった
        case linked
        /// この Apple アカウントのサブスクリプションは、ほかの nu-tori のアカウントのもの
        case ownedByOtherAccount
        /// 今使える取引が無い
        case nothingToRestore
        /// Apple アカウントへのサインインを閉じた
        case cancelled
        case failed(RequestFailureReason)

        /// 1つでも結びついたら結びついた、でなければ1つでもほかのアカウントのものならそれを返す
        fileprivate init(_ outcomes: [ReportOutcome]) {
            if outcomes.isEmpty {
                self = .nothingToRestore
            } else if outcomes.contains(.linked) {
                self = .linked
            } else if outcomes.contains(.ownedByOtherAccount) {
                self = .ownedByOtherAccount
            } else if outcomes.contains(.notReported(.unreachable)) {
                self = .failed(.unreachable)
            } else {
                self = .failed(.retryLater)
            }
        }
    }

    public enum AutoRenewal: Sendable, Equatable {
        case on
        /// 解約した。サブスクリプションの終わりまで使える
        case off
        /// 今使えるサブスクリプションが無いか、更新の情報を読めない
        case unknown
    }

    /// 1つの取引を知らせた結果
    fileprivate enum ReportOutcome: Sendable, Equatable {
        case linked
        case ownedByOtherAccount
        case rejected
        case notReported(RequestFailureReason)
    }

    private let store: any SubscriptionStore
    private let client: NuToriAPIClient
    private let applyReportedChanges: @Sendable ([SyncChange]) async throws -> Void
    private let errorReporting: any ErrorReportingSession
    private let newRequestId: @Sendable () -> UUID

    /// 知らせている途中の取引。`Transaction.updates` と終えていない取引に同じ取引が流れても、1度だけ送る
    private var inFlight: [UInt64: Task<ReportOutcome, Never>] = [:]
    /// この起動で知らせて終えた取引。終えたあとに `Transaction.updates` に流れても送らない
    private var settled: [UInt64: ReportOutcome] = [:]
    /// 取引ごとの、まだ答えを受け取っていない要求の ID。知らせ直すときは同じ ID で送る
    private var requestIds: [UInt64: UUID] = [:]

    private func report(
        _ transaction: AppStoreTransaction, trigger: NuToriAPIClient.SubscriptionTransactionTrigger
    )
        async -> ReportOutcome
    {
        if let running = inFlight[transaction.id] {
            return await running.value
        }
        // 復元は、人が求めたので、この起動で知らせた取引も送り直す
        if trigger != .restore, let outcome = settled[transaction.id] {
            return outcome
        }
        let task = Task { await self.send(transaction, trigger: trigger) }
        inFlight[transaction.id] = task
        let outcome = await task.value
        inFlight[transaction.id] = nil
        return outcome
    }

    private func send(
        _ transaction: AppStoreTransaction, trigger: NuToriAPIClient.SubscriptionTransactionTrigger
    )
        async -> ReportOutcome
    {
        let requestId = requestIds[transaction.id] ?? newRequestId()
        requestIds[transaction.id] = requestId
        let result: NuToriAPIClient.SubscriptionTransactionReportResult
        do {
            result = try await client.reportSubscriptionTransaction(
                requestId: requestId, signedTransaction: transaction.signedTransaction,
                trigger: trigger)
        } catch {
            return .notReported(RequestFailureReason(error))
        }
        let outcome: ReportOutcome
        switch result {
        case .linked(let changes):
            // 当てられなくても、同じ記録が同期で届く
            try? await applyReportedChanges(changes)
            outcome = .linked
        case .ownedByOtherAccount:
            outcome = .ownedByOtherAccount
        // 署名・環境・商品はどれも取引の中身で決まり、送り直しても同じ答えになる。終えずに残すと、開くたびに送り続ける。
        // 終えても、今使える取引は「購入を復元」で、本番の取引は App Store のサーバー通知で、サーバーを直したあとに届け直せる
        case .rejected:
            outcome = .rejected
        // 届いたが受け付けられなかったので、終えずに残し、次に開いたときに同じ要求の ID で送り直す
        case .badRequest, .sessionExpired, .rateLimited:
            return .notReported(.retryLater)
        }
        await store.finish(transaction)
        requestIds[transaction.id] = nil
        settled[transaction.id] = outcome
        return outcome
    }
}
