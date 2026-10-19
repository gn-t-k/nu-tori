import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("週の見直しの同期の形")
struct WeeklyReviewSyncingTests {
    static let reviewedAt = Date(timeIntervalSince1970: 1_792_368_000)

    /// 10月19日の月曜から新しい1日の目安を当てる見直しが届くときの形
    static func synced(
        id: UUID, effectiveOn: String = "2026-10-19", outcome: SyncedWeeklyReview.Outcome
    ) throws -> SyncedWeeklyReview {
        SyncedWeeklyReview(
            id: id, effectiveOn: effectiveOn, reviewedAt: reviewedAt,
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")), outcome: outcome)
    }

    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = WeeklyReviewSyncing()
        let cache = MemoryKeyedRecordCache<WeeklyReview, UUID>(id: \.id)
        let reviewedId = UUID()
        let deferredId = UUID()
        // どれもキャッシュに無い。見直しは、指す推定消費カロリー・1日の目安・目標より先に届くことがある
        let estimateId = UUID()
        let guideId = UUID()
        let goalId = UUID()

        init() throws {
            try syncing.apply(
                [
                    .weeklyReview(
                        try WeeklyReviewSyncingTests.synced(
                            id: reviewedId,
                            outcome: .reviewed(
                                expenditureEstimateId: estimateId, dailyGuideId: guideId,
                                mainReason: .expenditureChange))),
                    .weeklyReview(
                        try WeeklyReviewSyncingTests.synced(
                            id: deferredId, effectiveOn: "2026-10-26",
                            outcome: .deferred(reason: .withinFirstWeek, goalId: goalId))),
                ], to: cache)
        }

        @Test("指す記録より先に届いた見直せた週と見送った週が、当てる月曜と結果を持ってキャッシュに入ること")
        func storesArrivedReviews() throws {
            let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
            #expect(
                Set(cache.all()) == [
                    WeeklyReview(
                        id: reviewedId, effectiveDay: CalendarDay(year: 2026, month: 10, day: 19),
                        reviewedAt: WeeklyReviewSyncingTests.reviewedAt, timeZone: tokyo,
                        outcome: .reviewed(
                            expenditureEstimateId: estimateId, dailyGuideId: guideId,
                            mainReason: .expenditureChange)),
                    WeeklyReview(
                        id: deferredId, effectiveDay: CalendarDay(year: 2026, month: 10, day: 26),
                        reviewedAt: WeeklyReviewSyncingTests.reviewedAt, timeZone: tokyo,
                        outcome: .deferred(reason: .withinFirstWeek, goalId: goalId)),
                ])
        }

        @Test("同じ見直しが届き直すと、行を増やさずその値にそろえること")
        func overwritesWithArrivedValue() throws {
            try syncing.apply(
                [
                    .weeklyReview(
                        try WeeklyReviewSyncingTests.synced(
                            id: deferredId, effectiveOn: "2026-10-26",
                            outcome: .deferred(reason: .noWeight, goalId: goalId)))
                ], to: cache)

            let deferred = try #require(cache.all().first { $0.id == deferredId })
            #expect(cache.all().count == 2)
            #expect(deferred.outcome == .deferred(reason: .noWeight, goalId: goalId))
        }

        @Test("当てる月曜が読めない見直しは、キャッシュに入れないこと")
        func skipsUnreadableEffectiveDay() throws {
            try syncing.apply(
                [
                    .weeklyReview(
                        try WeeklyReviewSyncingTests.synced(
                            id: UUID(), effectiveOn: "来週",
                            outcome: .deferred(reason: .fewMealRecords, goalId: goalId)))
                ], to: cache)

            #expect(Set(cache.all().map(\.id)) == [reviewedId, deferredId])
        }

        @Test("ほかの種類の変更は、キャッシュを変えないこと")
        func skipsOtherKinds() throws {
            try syncing.apply([.mealDeletion(mealId: reviewedId)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、見直しがキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}
