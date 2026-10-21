public import Foundation

/// サブスクリプションの状態。サーバーが事実から計算して届ける。アカウントに1つ。
/// 日付と時刻は事実が変わったときだけ変わるので、端末は今日と比べて描く（`SubscriptionStanding`）
public enum SubscriptionStatus: Hashable, Sendable {
    /// テストユーザー。いつもサブスクリプション中と同じに扱い、無料体験のカードも日数も出さない
    case testUser
    case regular(freeTrial: FreeTrial, subscription: Subscription)

    public enum FreeTrial: Hashable, Sendable {
        /// 無料体験の最後の日。その日の終わり（端末のタイムゾーン）までが無料体験中
        case available(lastDay: CalendarDay)
        /// 作り直したアカウント。無料体験が無い
        case usedByEarlierAccount
    }

    public enum Subscription: Hashable, Sendable {
        /// 取り消されていない取引が無い（買っていない、またはすべて取り消された）
        case none
        /// 期限がいちばん遅い取り消されていない取引の商品と期限（アカウントの行の更新日）
        case subscribed(plan: Plan, periodEndsAt: Date, billingGrace: BillingGrace)
    }

    public enum Plan: Hashable, Sendable {
        case monthly
        case yearly
    }

    public enum BillingGrace: Hashable, Sendable {
        case none
        /// 請求の猶予の終わり。期限より遅いときだけ届く
        case granted(endsAt: Date)
    }
}

extension SubscriptionStatus.Subscription {
    /// サブスクリプションの終わり。猶予があればその終わり、無ければ期限。比べるのはサーバーなので、端末は比べずに選ぶ
    public var endsAt: Date? {
        switch self {
        case .none: nil
        case .subscribed(_, let periodEndsAt, .none): periodEndsAt
        case .subscribed(_, _, .granted(let endsAt)): endsAt
        }
    }
}
