import Foundation
import NuToriCore
import Testing

extension TimelineSnapshot {
    /// 東京の 2026-11-02 12:00 の表示の値。渡さなかった記録は空のもので、初回の取得は 2026-10-01 に使い始めて終えている
    static func fixture(
        weightRecords: [WeightRecord] = [], notices: [Notice] = [], goals: [Goal] = [],
        dailyGuides: [DailyGuide] = [], subscriptionStatus: SubscriptionStatus? = nil,
        initialPull: InitialPull = .completed(
            startedDay: CalendarDay(year: 2026, month: 10, day: 1))
    ) throws -> TimelineSnapshot {
        TimelineSnapshot(
            weightRecords: weightRecords, weightTrend: nil, initialPull: initialPull,
            rejectedLines: [], meals: [], notices: notices, goals: goals,
            dailyGuides: dailyGuides, weeklyReviews: [], expenditureEstimates: [],
            subscriptionStatus: subscriptionStatus, undelivered: .none, conversation: .none,
            today: fixtureToday, now: try Date("2026-11-02T12:00:00+09:00", strategy: .iso8601),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))
    }

    static let fixtureToday = CalendarDay(year: 2026, month: 11, day: 2)
}
