public import Foundation
public import Observation

/// 課金画面を1回開いてから閉じるまで。購入者のトークンを求め、`SubscriptionStoreView` で買えた取引と「購入を復元」を知らせ、結果の1行と閉じるかを決め、開いた・閉じたを PostHog に送る
@MainActor
@Observable
public final class PaywallSession {
    /// 購入の選択肢に渡す購入者のトークン。受け取るまで買えない
    public private(set) var purchaseToken: PurchaseToken = .requesting
    /// 購入と復元の結果の1行
    public private(set) var message: String?
    /// 結びついたので、シートを閉じる
    public private(set) var isFinished = false

    /// - Parameter standing: 開いたときのサブスクリプションの状態。PostHog に送る
    public init(
        entry: ClientUsageEvent.PaywallEntry,
        standing: SubscriptionStanding,
        purchases: SubscriptionPurchases,
        capture: @escaping (ClientUsageEvent) async -> Void
    ) {
        self.entry = entry
        self.standing = standing
        self.purchases = purchases
        self.capture = capture
    }

    public enum PurchaseToken: Equatable, Sendable {
        case requesting
        case issued(UUID)
        case unavailable
    }

    public func open() async {
        await capture(.paywallOpened(entry: entry, standing: standing))
        switch await purchases.appAccountToken() {
        case .issued(let token):
            purchaseToken = .issued(token)
        case .unavailable(let reason):
            purchaseToken = .unavailable
            message =
                switch reason {
                case .unreachable:
                    "インターネットにつながらないため、今は始められません。つながるところで、もう一度開いてください。"
                case .retryLater: "今は始められません。時間をおいて、もう一度開いてください。"
                }
        }
    }

    /// `SubscriptionStoreView` で買う操作が終わった
    public func purchaseCompleted(_ attempt: AppStorePurchaseAttempt) async {
        switch attempt {
        case .purchased(let transaction):
            result = .purchased
            show(await purchases.reportPurchase(transaction))
        case .cancelled:
            message = nil
        case .pending:
            result = .pending
            message = "承認を待っています。承認されると、使えるようになります。"
        }
    }

    /// StoreKit が買えなかった
    public func purchaseFailed() {
        message = "始められませんでした。時間をおいて、もう一度お試しください。"
    }

    /// 「購入を復元」
    public func restore() async {
        switch await purchases.restore() {
        case .linked:
            isFinished = true
        case .ownedByOtherAccount:
            message = Self.ownedByOtherAccount
        case .nothingToRestore:
            message = "復元できるサブスクリプションがありません"
        case .cancelled:
            message = nil
        case .failed(.unreachable):
            message = "インターネットにつながらないため、復元できませんでした。つながるところで、もう一度押してください。"
        case .failed(.retryLater):
            message = "復元できませんでした。時間をおいて、もう一度押してください。"
        }
    }

    /// シートが閉じた
    public func close() async {
        await capture(.paywallClosed(result))
    }

    private static let ownedByOtherAccount = "このサブスクリプションは、ほかの nu-tori のアカウントで使っています"

    private let entry: ClientUsageEvent.PaywallEntry
    private let standing: SubscriptionStanding
    private let purchases: SubscriptionPurchases
    private let capture: (ClientUsageEvent) async -> Void
    /// 閉じるまでの StoreKit の購入の結果。買わずに閉じたときは取り消した
    private var result = ClientUsageEvent.PaywallResult.cancelled

    private func show(_ outcome: SubscriptionPurchases.PurchaseOutcome) {
        switch outcome {
        case .linked:
            message = nil
            isFinished = true
        case .ownedByOtherAccount:
            message = Self.ownedByOtherAccount
        // 取引は終えずに残してあり、開いたとき（前面に来たとき）に知らせ直す
        case .notLinkedYet:
            message = "支払いは済みました。インターネットにつながるところでアプリを開き直すと、使えるようになります。"
        // 取引は終えてあり、App Store のサーバー通知か「購入を復元」で届け直す
        case .rejected:
            message = "支払いは済みましたが、まだ使えるようになっていません。時間をおいて「購入を復元」を押してください。"
        }
    }
}
