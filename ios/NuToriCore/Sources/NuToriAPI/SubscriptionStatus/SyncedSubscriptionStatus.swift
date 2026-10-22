public import Foundation

/// サブスクリプションの状態。サーバーだけが書き、事実から計算する。アカウントに1つで、記録の ID は最初のサインインの ID。消えない。
/// 日付と時刻は事実が変わったときだけ変わるので、端末は今日と比べて描く
public enum SyncedSubscriptionStatus: Sendable, Equatable {
    /// テストユーザー。いつもサブスクリプション中と同じに扱う
    case testUser
    case regular(freeTrial: FreeTrial, subscription: Subscription)

    public enum FreeTrial: Sendable, Equatable {
        /// 無料体験の最後の日（YYYY-MM-DD）。その日の終わりまでが無料体験中
        case available(lastDay: String)
        /// 作り直したアカウント。無料体験が無い
        case usedByEarlierAccount
    }

    public enum Subscription: Sendable, Equatable {
        /// 取り消されていない取引が無い（買っていない、またはすべて取り消された）
        case none
        /// 期限がいちばん遅い取り消されていない取引の商品と期限
        case subscribed(plan: Plan, periodEndsAt: Date, billingGrace: BillingGrace)
    }

    /// サーバーの `plan` の値
    public enum Plan: String, Sendable, Equatable {
        case monthly
        case yearly
    }

    public enum BillingGrace: Sendable, Equatable {
        case none
        /// 請求の猶予の終わり。期限より遅いときだけ届く（比べるのはサーバー）
        case granted(endsAt: Date)
    }
}
