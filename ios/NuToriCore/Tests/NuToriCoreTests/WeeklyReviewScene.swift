import Foundation
import NuToriCore
import Testing

/// `Goal.losing()` と、その始めの推定消費カロリーと1日の目安、10月5日に見直した推定消費カロリーと1日の目安
struct WeeklyReviewScene {
    let goal: Goal
    let initialEstimate: ExpenditureEstimate
    let initialGuide: DailyGuide
    /// 10月5日から当てる 2,140 kcal
    let reviewedEstimate: ExpenditureEstimate
    /// 10月5日から当てる 1,850 kcal
    let reviewedGuide: DailyGuide
    let tokyo: TimeZone

    init(goal: Goal? = nil) throws {
        let goal = try goal ?? Goal.losing()
        self.goal = goal
        tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let start = CalendarDay(year: 2026, month: 10, day: 1)
        initialEstimate = ExpenditureEstimate(
            id: UUID(), effectiveDay: start, expenditureKilocalories: 2190,
            estimatedAt: goal.decidedAt, initialSource: .backCalculated)
        initialGuide = DailyGuide(
            id: UUID(), goalId: goal.id, expenditureEstimateId: initialEstimate.id,
            effectiveDay: start, energyKilocalories: 1880, proteinGrams: 110, fatGrams: 52,
            carbohydrateGrams: 245, limitHits: [])
        let monday = CalendarDay(year: 2026, month: 10, day: 5)
        reviewedEstimate = ExpenditureEstimate(
            id: UUID(), effectiveDay: monday, expenditureKilocalories: 2140,
            estimatedAt: try Date("2026-10-05T06:10:00+09:00", strategy: .iso8601),
            initialSource: nil)
        reviewedGuide = DailyGuide(
            id: UUID(), goalId: goal.id, expenditureEstimateId: reviewedEstimate.id,
            effectiveDay: monday, energyKilocalories: 1850, proteinGrams: 110, fatGrams: 50,
            carbohydrateGrams: 240, limitHits: [])
    }

    func estimate(effectiveOn day: CalendarDay, kilocalories: Int) -> ExpenditureEstimate {
        ExpenditureEstimate(
            id: UUID(), effectiveDay: day, expenditureKilocalories: kilocalories,
            estimatedAt: goal.decidedAt, initialSource: nil)
    }

    func guide(
        estimate: ExpenditureEstimate, effectiveOn day: CalendarDay, kilocalories: Int,
        goalId: UUID? = nil
    ) -> DailyGuide {
        DailyGuide(
            id: UUID(), goalId: goalId ?? goal.id, expenditureEstimateId: estimate.id,
            effectiveDay: day, energyKilocalories: kilocalories, proteinGrams: 110, fatGrams: 50,
            carbohydrateGrams: 240, limitHits: [])
    }

    func reviewed(
        effectiveOn day: CalendarDay, reviewedAt: String, guide: DailyGuide,
        estimate: ExpenditureEstimate, mainReason: WeeklyReview.MainReason
    ) throws -> WeeklyReview {
        WeeklyReview(
            id: UUID(), effectiveDay: day,
            reviewedAt: try Date(reviewedAt, strategy: .iso8601), timeZone: tokyo,
            outcome: .reviewed(
                expenditureEstimateId: estimate.id, dailyGuideId: guide.id,
                mainReason: mainReason))
    }

    func deferred(effectiveOn day: CalendarDay, reviewedAt: String) throws -> WeeklyReview {
        WeeklyReview(
            id: UUID(), effectiveDay: day,
            reviewedAt: try Date(reviewedAt, strategy: .iso8601), timeZone: tokyo,
            outcome: .deferred(reason: .fewMealRecords, goalId: goal.id))
    }

    /// 使い始めた日は目標の開始の日（10月1日）
    func timeline(
        reviews: [WeeklyReview], goals: [Goal]? = nil, includesReviewedGuide: Bool = true,
        extraEstimates: [ExpenditureEstimate] = [], extraGuides: [DailyGuide] = [],
        weightRecords: [WeightRecord], weightTrend: WeightTrend? = nil, today: CalendarDay
    ) -> Timeline {
        Timeline(
            input: Timeline.Input(
                goalRecords: .fixture(
                    goals: goals ?? [goal],
                    dailyGuides: [initialGuide] + (includesReviewedGuide ? [reviewedGuide] : [])
                        + extraGuides,
                    expenditureEstimates: [initialEstimate, reviewedEstimate] + extraEstimates,
                    weeklyReviews: reviews, weightTrend: weightTrend, weightRecords: weightRecords),
                rejectedLines: [], meals: [], notices: [], undelivered: .none, conversation: .none),
            firstDay: CalendarDay(year: 2026, month: 10, day: 1), today: today)
    }

    static func itemIds(on day: CalendarDay, in timeline: Timeline) -> [String] {
        timeline.days.first { $0.day == day }?.items.map(\.id) ?? []
    }

    static func card(in timeline: Timeline) -> WeeklyReviewCard? {
        timeline.days.lazy.flatMap(\.items).compactMap { item -> WeeklyReviewCard? in
            if case .weeklyReviewCard(let card) = item { card } else { nil }
        }.first
    }

    static func changeNotice(in timeline: Timeline) -> DailyGuideChangeNotice? {
        timeline.days.lazy.flatMap(\.items).compactMap { item -> DailyGuideChangeNotice? in
            if case .dailyGuideChangeNotice(let notice) = item { notice } else { nil }
        }.first
    }
}
