public import Foundation

/// アカウントの画面の一番上の「サブスクリプション」の行。審査の人も、無料体験中のアカウントでこの行から課金画面に届く
public struct AccountSubscriptionRow: Equatable, Sendable {
    public let value: String
    /// 無料体験中だけ持つ
    public let note: String?
    /// テストユーザーは開かない
    public let opensPaywall: Bool

    /// 日付は端末のタイムゾーンで書く。自動更新がオフなら、解約したこととサブスクリプションの終わりを書く
    public init(
        standing: SubscriptionStanding, autoRenewal: SubscriptionPurchases.AutoRenewal,
        timeZone: TimeZone
    ) {
        switch standing {
        case .testUser:
            value = "テストユーザー"
            note = nil
            opensPaywall = false
        case .freeTrial(let lastDay, let remainingDays):
            value = "無料体験 あと \(remainingDays) 日"
            note = "無料体験は\(GoalText.monthDay(lastDay))まで。そのあとも体重の記録と、これまでの記録の見返しはできます。"
            opensPaywall = true
        case .subscribed(let plan, let periodEndsAt, let endsAt):
            switch autoRenewal {
            case .off:
                let endDay = CalendarDay(containing: endsAt, in: timeZone)
                value = "解約しました・\(GoalText.monthDay(endDay))まで使えます"
            case .on, .unknown:
                let renewalDay = CalendarDay(containing: periodEndsAt, in: timeZone)
                value = "\(plan.name)・\(GoalText.monthDay(renewalDay))に更新"
            }
            note = nil
            opensPaywall = true
        case .expired:
            value = "サブスクリプション切れ"
            note = nil
            opensPaywall = true
        }
    }
}

extension SubscriptionStatus.Plan {
    /// 「月額」「年額」
    var name: String {
        switch self {
        case .monthly: "月額"
        case .yearly: "年額"
        }
    }
}
