import Foundation
import NuToriCore
import SwiftData

/// サブスクリプションの状態。アカウントに1つなので、行は1つだけ置く。
/// 分かれる形を、省略できる列で平らに持つ（テストユーザーはほかの列を持たない）
@Model
nonisolated final class CachedSubscriptionStatus {
    @Attribute(.unique) var singletonKey: String
    /// テストユーザーか
    var isTestUser: Bool
    /// 無料体験の最後の日（YYYY-MM-DD）。作り直したアカウントとテストユーザーは nil
    var freeTrialLastDay: String?
    /// 商品（monthly・yearly）。取り消されていない取引が無ければ nil
    var plan: String?
    /// 期限。商品があるときだけ持つ
    var periodEndsAt: Date?
    /// 請求の猶予の終わり。期限より遅い猶予があるときだけ持つ
    var billingGraceEndsAt: Date?

    init(_ status: SubscriptionStatus) {
        singletonKey = Self.onlyKey
        isTestUser = false
        apply(status)
    }

    func apply(_ status: SubscriptionStatus) {
        switch status {
        case .testUser:
            isTestUser = true
            freeTrialLastDay = nil
            plan = nil
            periodEndsAt = nil
            billingGraceEndsAt = nil
        case .regular(let freeTrial, let subscription):
            isTestUser = false
            freeTrialLastDay =
                switch freeTrial {
                case .available(let lastDay): lastDay.yearMonthDay
                case .usedByEarlierAccount: nil
                }
            switch subscription {
            case .none:
                plan = nil
                periodEndsAt = nil
                billingGraceEndsAt = nil
            case .subscribed(let subscribedPlan, let endsAt, let billingGrace):
                plan =
                    switch subscribedPlan {
                    case .monthly: "monthly"
                    case .yearly: "yearly"
                    }
                periodEndsAt = endsAt
                billingGraceEndsAt =
                    switch billingGrace {
                    case .none: nil
                    case .granted(let graceEndsAt): graceEndsAt
                    }
            }
        }
    }

    /// 読めない値の行は nil
    func subscriptionStatus() -> SubscriptionStatus? {
        if isTestUser { return .testUser }
        let freeTrial: SubscriptionStatus.FreeTrial
        if let freeTrialLastDay {
            guard let lastDay = CalendarDay(yearMonthDay: freeTrialLastDay) else { return nil }
            freeTrial = .available(lastDay: lastDay)
        } else {
            freeTrial = .usedByEarlierAccount
        }
        guard let plan else {
            return .regular(freeTrial: freeTrial, subscription: .none)
        }
        let subscribedPlan: SubscriptionStatus.Plan
        switch plan {
        case "monthly": subscribedPlan = .monthly
        case "yearly": subscribedPlan = .yearly
        // swiftlint:disable:next no_default_in_switch - 行の値は文字列で、知らない値がありうる
        default: return nil
        }
        guard let periodEndsAt else { return nil }
        return .regular(
            freeTrial: freeTrial,
            subscription: .subscribed(
                plan: subscribedPlan, periodEndsAt: periodEndsAt,
                billingGrace: billingGraceEndsAt.map { .granted(endsAt: $0) } ?? .none))
    }

    static let onlyKey = "subscription-status"
}
