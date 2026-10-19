import Foundation
import NuToriCore
import SwiftData

/// 週の見直し。見直せた週の値（指す推定と1日の目安、主な理由）か、見送った週の値（理由と目標）のどちらかを同じ行に持つ
@Model
nonisolated final class CachedWeeklyReview {
    @Attribute(.unique) var reviewId: UUID
    /// YYYY-MM-DD。新しい1日の目安を当てる月曜
    var effectiveDay: String
    var reviewedAt: Date
    var timeZoneIdentifier: String
    /// 見直せた週だけにある
    var expenditureEstimateId: UUID?
    /// 見直せた週だけにある
    var dailyGuideId: UUID?
    /// expenditure_change・balance_change。見直せた週だけにある
    var mainReason: String?
    /// within_first_week・no_weight・few_meal_records。見送った週だけにある
    var deferralReason: String?
    /// 見送った週だけにある
    var goalId: UUID?

    init(_ review: WeeklyReview) {
        let stored = Stored(review.outcome)
        reviewId = review.id
        effectiveDay = review.effectiveDay.yearMonthDay
        reviewedAt = review.reviewedAt
        timeZoneIdentifier = review.timeZone.identifier
        expenditureEstimateId = stored.expenditureEstimateId
        dailyGuideId = stored.dailyGuideId
        mainReason = stored.mainReason
        deferralReason = stored.deferralReason
        goalId = stored.goalId
    }

    /// 見直しは変わらないが、同じ ID が届き直したときはその値にそろえる
    func apply(_ review: WeeklyReview) {
        let stored = Stored(review.outcome)
        effectiveDay = review.effectiveDay.yearMonthDay
        reviewedAt = review.reviewedAt
        timeZoneIdentifier = review.timeZone.identifier
        expenditureEstimateId = stored.expenditureEstimateId
        dailyGuideId = stored.dailyGuideId
        mainReason = stored.mainReason
        deferralReason = stored.deferralReason
        goalId = stored.goalId
    }

    /// 読めない日付・タイムゾーン・理由の行と、見直せた週の値も見送った週の値もそろわない行は nil
    func weeklyReview() -> WeeklyReview? {
        guard let effectiveDay = CalendarDay(yearMonthDay: effectiveDay),
            let timeZone = TimeZone(identifier: timeZoneIdentifier),
            let outcome = outcome()
        else { return nil }
        return WeeklyReview(
            id: reviewId, effectiveDay: effectiveDay, reviewedAt: reviewedAt, timeZone: timeZone,
            outcome: outcome)
    }

    private func outcome() -> WeeklyReview.Outcome? {
        if let expenditureEstimateId, let dailyGuideId, let mainReason, deferralReason == nil,
            goalId == nil
        {
            let reason: WeeklyReview.MainReason? =
                switch mainReason {
                case "expenditure_change": .expenditureChange
                case "balance_change": .balanceChange
                default: nil
                }
            return reason.map {
                .reviewed(
                    expenditureEstimateId: expenditureEstimateId, dailyGuideId: dailyGuideId,
                    mainReason: $0)
            }
        }
        if let deferralReason, let goalId, expenditureEstimateId == nil, dailyGuideId == nil,
            mainReason == nil
        {
            let reason: WeeklyReview.DeferralReason? =
                switch deferralReason {
                case "within_first_week": .withinFirstWeek
                case "no_weight": .noWeight
                case "few_meal_records": .fewMealRecords
                default: nil
                }
            return reason.map { .deferred(reason: $0, goalId: goalId) }
        }
        return nil
    }

    /// 見直せたか見送ったかを、行の列の形にしたもの。付かない列は nil
    private struct Stored {
        var expenditureEstimateId: UUID?
        var dailyGuideId: UUID?
        var mainReason: String?
        var deferralReason: String?
        var goalId: UUID?

        init(_ outcome: WeeklyReview.Outcome) {
            switch outcome {
            case .reviewed(let estimateId, let guideId, let reason):
                expenditureEstimateId = estimateId
                dailyGuideId = guideId
                mainReason =
                    switch reason {
                    case .expenditureChange: "expenditure_change"
                    case .balanceChange: "balance_change"
                    }
            case .deferred(let reason, let deferredGoalId):
                deferralReason =
                    switch reason {
                    case .withinFirstWeek: "within_first_week"
                    case .noWeight: "no_weight"
                    case .fewMealRecords: "few_meal_records"
                    }
                goalId = deferredGoalId
            }
        }
    }
}
