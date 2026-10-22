public import Foundation

/// 無料体験とサブスクリプションの知らせ。知らせの行（`Notice`）を持たず、サブスクリプションの状態の日付と端末の今日から描く。
/// 答えも閉じるボタンも持たず、帯の下の「答えていない知らせ」の1行に数えない。
/// 条件は今の状態で決めるので、買ったら過ぎた日のカードも出なくなる。その日のタイムラインの先頭に置く
public struct SubscriptionNotice: Hashable, Sendable {
    public let kind: Kind
    /// カードを置くタイムラインの日
    public let day: CalendarDay

    public init(kind: Kind, day: CalendarDay) {
        self.kind = kind
        self.day = day
    }

    public enum Kind: Hashable, Sendable {
        /// 無料体験のあと3日。最後の日の2日前に置く
        case freeTrialEndsSoon(lastDay: CalendarDay)
        /// 無料体験の最後の日。その日に置く
        case freeTrialLastDay
        /// 無料体験が終わった。最後の日の次の日に置く
        case freeTrialEnded
        /// サブスクリプションが終わった。サブスクリプションの終わりを含む日に置く
        case subscriptionEnded
        /// 作り直したアカウントで、無料体験が無い。最初のサインインの日に置く
        case noFreeTrial

        /// タイムラインの項目の ID に入れる
        var idSuffix: String {
            switch self {
            case .freeTrialEndsSoon: "free-trial-ends-soon"
            case .freeTrialLastDay: "free-trial-last-day"
            case .freeTrialEnded: "free-trial-ended"
            case .subscriptionEnded: "subscription-ended"
            case .noFreeTrial: "no-free-trial"
            }
        }
    }

    /// 今日までに置く知らせを、置く日の古い順に出す。今日より後の日の知らせは出さない。
    /// `firstSignInDay` は最初のサインインの日（使い始めた日）で、無料体験が無い知らせを置く
    public static func notices(
        status: SubscriptionStatus, now: Date, timeZone: TimeZone, firstSignInDay: CalendarDay
    ) -> [SubscriptionNotice] {
        guard case .regular(let freeTrial, let subscription) = status else { return [] }
        let standing = SubscriptionStanding(status: status, now: now, timeZone: timeZone)
        let today = CalendarDay(containing: now, in: timeZone)
        let endDay = subscription.endsAt.map { CalendarDay(containing: $0, in: timeZone) }
        let isSubscribed = if case .subscribed = standing { true } else { false }
        var notices: [SubscriptionNotice] = []
        if case .available(let lastDay) = freeTrial {
            if !isSubscribed {
                notices.append(
                    .init(kind: .freeTrialEndsSoon(lastDay: lastDay), day: lastDay.advanced(by: -2))
                )
                notices.append(.init(kind: .freeTrialLastDay, day: lastDay))
            }
            if standing.isExpired {
                let dayAfterLastDay = lastDay.advanced(by: 1)
                if let endDay, endDay >= dayAfterLastDay {
                    notices.append(.init(kind: .subscriptionEnded, day: endDay))
                } else {
                    notices.append(.init(kind: .freeTrialEnded, day: dayAfterLastDay))
                }
            }
        } else if standing.isExpired {
            if let endDay {
                notices.append(.init(kind: .subscriptionEnded, day: endDay))
            } else {
                notices.append(.init(kind: .noFreeTrial, day: firstSignInDay))
            }
        }
        return notices.filter { $0.day <= today }
    }

    public var title: String {
        switch kind {
        case .freeTrialEndsSoon: "無料体験はあと 3 日"
        case .freeTrialLastDay: "無料体験は今日まで"
        case .freeTrialEnded: "無料体験が終わりました"
        case .subscriptionEnded: "サブスクリプションが終わりました"
        case .noFreeTrial: "無料体験はありません"
        }
    }

    public var body: String {
        switch kind {
        case .freeTrialEndsSoon(let lastDay):
            "\(GoalText.monthDay(lastDay))で終わります。そのあとも体重の記録と、これまでの記録の見返しはできます。"
        case .freeTrialLastDay:
            "明日から、撮って記録するにはサブスクリプションが必要です。体重の記録と見返しはそのままできます。"
        case .freeTrialEnded, .subscriptionEnded:
            "体重の記録と、これまでの記録の見返しはこれまでどおりできます。\(Self.needsSubscription)"
        case .noFreeTrial:
            "このアカウントは、前に無料体験を使った Apple ID で作られました。体重の記録と、これまでの記録の見返しはできます。\(Self.needsSubscription)"
        }
    }

    /// 課金画面を開く「サブスクリプションを見る」を置くか。切れの知らせには置かない（入口は入力欄の上のチップにいつもあるため）
    public var showsSubscriptionButton: Bool {
        switch kind {
        case .freeTrialEndsSoon, .freeTrialLastDay: true
        case .freeTrialEnded, .subscriptionEnded, .noFreeTrial: false
        }
    }

    /// 「サブスクリプションを見る」の文言
    public static let subscriptionButtonTitle = "サブスクリプションを見る"

    private static let needsSubscription =
        "写真から食事を記録すること、1日の目安の見直し、書いた文への返事には、サブスクリプションが必要です。"
}
