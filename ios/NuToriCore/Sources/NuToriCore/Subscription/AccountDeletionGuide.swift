public import Foundation

/// 退会の案内のシートの中身。サブスクリプション中で自動更新がオンの人が「アカウントを削除」を押すと、確かめの前に出し、
/// アカウントを削除しても Apple の請求が続くことと、解約の道を示す
public struct AccountDeletionGuide: Sendable, Equatable {
    public let plan: SubscriptionStatus.Plan
    /// 次の更新日（期限を含む日）。解約しても、この日まで使える
    public let renewsOn: CalendarDay
    /// サブスクリプションの終わりを含む日。解約したあとの「使える日」
    public let usableThrough: CalendarDay
    /// 次の請求の額（App Store が出す価格）。商品を読めないときは無い
    public let displayPrice: String?
    public let renewal: Renewal

    public init(
        plan: SubscriptionStatus.Plan, renewsOn: CalendarDay, usableThrough: CalendarDay,
        displayPrice: String?, renewal: Renewal
    ) {
        self.plan = plan
        self.renewsOn = renewsOn
        self.usableThrough = usableThrough
        self.displayPrice = displayPrice
        self.renewal = renewal
    }

    /// 案内を出すときだけ返す。出すのは、テストユーザーでなく、今サブスクリプション中で、自動更新がオンのとき
    public static func prepare(
        status: SubscriptionStatus?, now: Date, timeZone: TimeZone,
        purchases: SubscriptionPurchases
    ) async -> AccountDeletionGuide? {
        guard let status,
            case .subscribed(let plan, let periodEndsAt, let endsAt) = SubscriptionStanding(
                status: status, now: now, timeZone: timeZone)
        else { return nil }
        guard await purchases.autoRenewal() == .on else { return nil }
        let products = (try? await purchases.products()) ?? []
        return AccountDeletionGuide(
            plan: plan,
            renewsOn: CalendarDay(containing: periodEndsAt, in: timeZone),
            usableThrough: CalendarDay(containing: endsAt, in: timeZone),
            displayPrice: products.first { $0.plan == plan }?.displayPrice,
            renewal: .autoRenewing)
    }

    /// 解約の画面から戻ったときに、自動更新を読み直す。読めなければ変えない
    public func rereadingRenewal(purchases: SubscriptionPurchases) async -> AccountDeletionGuide {
        let renewal: Renewal
        switch await purchases.autoRenewal() {
        case .on: renewal = .autoRenewing
        case .off: renewal = .cancelled
        case .unknown: return self
        }
        return AccountDeletionGuide(
            plan: plan, renewsOn: renewsOn, usableThrough: usableThrough,
            displayPrice: displayPrice, renewal: renewal)
    }

    public enum Renewal: Sendable, Equatable {
        case autoRenewing
        /// 解約の画面で解約した。これから先の請求は無い
        case cancelled
    }
}
