import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("週の見直しのキャッシュの行")
struct CachedWeeklyReviewCacheTests {
    static func review(id: UUID = UUID(), day: Int, outcome: WeeklyReview.Outcome) throws
        -> WeeklyReview
    {
        WeeklyReview(
            id: id, effectiveDay: CalendarDay(year: 2026, month: 10, day: day),
            reviewedAt: Date(timeIntervalSince1970: 1_792_368_000),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")), outcome: outcome)
    }

    static func reviewed(id: UUID = UUID(), day: Int = 19) throws -> WeeklyReview {
        try review(
            id: id, day: day,
            outcome: .reviewed(
                expenditureEstimateId: UUID(), dailyGuideId: UUID(), mainReason: .balanceChange))
    }

    static func deferred(id: UUID = UUID(), day: Int = 26) throws -> WeeklyReview {
        try review(id: id, day: day, outcome: .deferred(reason: .fewMealRecords, goalId: UUID()))
    }

    @Suite("見直せた週と見送った週を足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedWeeklyReview>
        let reviewed: WeeklyReview
        let deferred: WeeklyReview

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataKeyedRecordCache(context: store.container.mainContext)
            reviewed = try CachedWeeklyReviewCacheTests.reviewed()
            deferred = try CachedWeeklyReviewCacheTests.deferred()
            try cache.upsert(reviewed)
            try cache.upsert(deferred)
            try cache.context.save()
        }

        @Test("足した見直しと同じ見直しを、見直せたか見送ったかを保って読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [reviewed, deferred])
        }

        @Test("同じ ID の見直しを足すと、行を増やさず値が替わること")
        func replaces() throws {
            let revised = try CachedWeeklyReviewCacheTests.deferred(id: reviewed.id, day: 19)

            try cache.upsert(revised)

            let saved = try cache.savedRecords()
            #expect(saved.count == 2)
            #expect(Set(saved) == [revised, deferred])
        }

        @Test("ID で消すと、その見直しの行だけが無くなること")
        func removesById() throws {
            try cache.remove(id: reviewed.id)

            #expect(try cache.savedRecords() == [deferred])
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("読めない月曜・タイムゾーン・理由の行と、見直しの値が欠けた行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedWeeklyReview>
        let readable: WeeklyReview

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            readable = try CachedWeeklyReviewCacheTests.reviewed()
            let unreadableDay = try CachedWeeklyReviewCacheTests.reviewed(day: 12)
            let unknownTimeZone = try CachedWeeklyReviewCacheTests.reviewed(day: 5)
            let unknownReason = try CachedWeeklyReviewCacheTests.deferred()
            let missingGuide = try CachedWeeklyReviewCacheTests.reviewed(day: 28)
            for review in [readable, unreadableDay, unknownTimeZone, unknownReason, missingGuide] {
                try cache.upsert(review)
            }
            try #require(try CachedWeeklyReview.find(id: unreadableDay.id, in: context))
                .effectiveDay = "先週"
            try #require(try CachedWeeklyReview.find(id: unknownTimeZone.id, in: context))
                .timeZoneIdentifier = "Mars/Olympus"
            try #require(try CachedWeeklyReview.find(id: unknownReason.id, in: context))
                .deferralReason = "reason_added_later"
            try #require(try CachedWeeklyReview.find(id: missingGuide.id, in: context))
                .dailyGuideId = nil
            try context.save()
        }

        @Test("読めない行を飛ばし、読める見直しだけを読むこと")
        func skipsUnreadableRows() throws {
            #expect(try cache.savedRecords() == [readable])
        }
    }
}
