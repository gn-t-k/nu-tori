/// App Store のサブスクリプションの商品
public struct SubscriptionProduct: Sendable, Equatable {
    public let id: String
    public let plan: SubscriptionStatus.Plan
    /// App Store が出す、通貨つきの価格（「¥980」）。手で書かない
    public let displayPrice: String

    public init(id: String, plan: SubscriptionStatus.Plan, displayPrice: String) {
        self.id = id
        self.plan = plan
        self.displayPrice = displayPrice
    }

    /// 商品の ID と月額か年額か。サーバーの `server/src/subscription/domain/subscription-transaction-fact.ts` と同じ組にする
    public static let ids: [String: SubscriptionStatus.Plan] = [
        "app.nu-tori.subscription.monthly": .monthly,
        "app.nu-tori.subscription.yearly": .yearly,
    ]
}
