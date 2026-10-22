public import Foundation

/// 端末の今日でのサブスクリプションの状態。届いた状態の日付と時刻を、端末の今と今日（端末のタイムゾーン）と比べて出す。
/// 電波がなくても、日付が変われば無料体験の残りの日数と切れたことを描くため、端末で決める（`ios/AGENTS.md` の「端末で行うもの」）。
/// アカウントの行・入力欄・知らせのカードが、これで形を選ぶ
public enum SubscriptionStanding: Hashable, Sendable {
    /// テストユーザー。サブスクリプション中と同じに扱う
    case testUser
    /// 無料体験中。`remainingDays` は今日を含む残りの日数で、最後の日は1、あと3日の日は3
    case freeTrial(lastDay: CalendarDay, remainingDays: Int)
    /// サブスクリプション中。`periodEndsAt` は更新日に使う期限、`endsAt` はサブスクリプションの終わり（猶予があればその終わり）
    case subscribed(plan: SubscriptionStatus.Plan, periodEndsAt: Date, endsAt: Date)
    /// サブスクリプション切れ。写真の推定・見直し・返事を使えない
    case expired

    /// テストユーザーならテストユーザー。今がサブスクリプションの終わりより前ならサブスクリプション中。
    /// 今日が無料体験の最後の日以前なら無料体験中。ほかはサブスクリプション切れ
    public init(status: SubscriptionStatus, now: Date, timeZone: TimeZone) {
        switch status {
        case .testUser:
            self = .testUser
        case .regular(let freeTrial, let subscription):
            if case .subscribed(let plan, let periodEndsAt, _) = subscription,
                let endsAt = subscription.endsAt, now < endsAt
            {
                self = .subscribed(plan: plan, periodEndsAt: periodEndsAt, endsAt: endsAt)
                return
            }
            let today = CalendarDay(containing: now, in: timeZone)
            if case .available(let lastDay) = freeTrial, today <= lastDay {
                self = .freeTrial(lastDay: lastDay, remainingDays: today.distance(to: lastDay) + 1)
            } else {
                self = .expired
            }
        }
    }

    /// サブスクリプション切れか。切れていれば、撮る・写真・書く欄を押せなくする
    public var isExpired: Bool {
        switch self {
        case .expired: true
        case .testUser, .freeTrial, .subscribed: false
        }
    }
}
