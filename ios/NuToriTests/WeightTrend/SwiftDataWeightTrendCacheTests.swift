import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

/// 体重の傾向は、1件の記録を日ごとの行に分けて持つ
@Suite("SwiftData の、体重の傾向のキャッシュ")
struct SwiftDataWeightTrendCacheTests {
    static func day(_ day: Int, _ kilograms: Double) -> WeightTrend.Day {
        WeightTrend.Day(day: CalendarDay(year: 2026, month: 9, day: day), kilograms: kilograms)
    }

    @Suite("まだ何も書いていないとき")
    @MainActor
    struct Empty {
        let store: SwiftDataSyncStore
        let cache: SwiftDataWeightTrendCache

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataWeightTrendCache(context: store.container.mainContext)
            cache.context.autosaveEnabled = false
        }

        @Test("読むと無いこと")
        func readsNothing() throws {
            #expect(try cache.savedRecord() == nil)
        }

        @Test("保存の前に書いた傾向も、空にできること")
        func clearsUnsavedTrend() throws {
            try cache.write(
                WeightTrend(days: [
                    SwiftDataWeightTrendCacheTests.day(20, 72.4),
                    SwiftDataWeightTrendCacheTests.day(21, 72.35),
                ]))

            try cache.clear()

            #expect(try cache.savedRecord() == nil)
        }
    }

    @Suite("3日分の傾向を書いたとき")
    @MainActor
    struct Written {
        let store: SwiftDataSyncStore
        let cache: SwiftDataWeightTrendCache
        let trend: WeightTrend

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataWeightTrendCache(context: store.container.mainContext)
            cache.context.autosaveEnabled = false
            trend = WeightTrend(days: [
                SwiftDataWeightTrendCacheTests.day(20, 72.4),
                SwiftDataWeightTrendCacheTests.day(21, 72.35),
                SwiftDataWeightTrendCacheTests.day(22, 72.123_456_789),
            ])
            try cache.write(trend)
            try cache.context.save()
        }

        @Test("書いた傾向と同じ傾向を、日の順に、丸めない値で読めること")
        func readsBackSameTrend() throws {
            #expect(try cache.savedRecord() == trend)
        }

        @Test("日が重なる別の並びを書くと、同じ日は値を替え、並びに無い日を消し、新しい日を足すこと")
        func replacesWithOverlappingDays() throws {
            let next = WeightTrend(days: [
                SwiftDataWeightTrendCacheTests.day(21, 72.5),
                SwiftDataWeightTrendCacheTests.day(22, 72.45),
                SwiftDataWeightTrendCacheTests.day(23, 72.3),
            ])

            try cache.write(next)

            #expect(try cache.savedRecord() == next)
            #expect(try cache.context.fetchCount(FetchDescriptor<CachedWeightTrendDay>()) == 3)
        }

        @Test("空にすると、読んでも無いこと")
        func clears() throws {
            try cache.clear()

            #expect(try cache.savedRecord() == nil)
        }

        @Test("空にしてから、同じ保存の前に同じ日を含む並びを書き直すと、書いた並びが残ること")
        func writesAfterClearing() throws {
            let again = WeightTrend(days: [
                SwiftDataWeightTrendCacheTests.day(22, 72.6),
                SwiftDataWeightTrendCacheTests.day(23, 72.55),
            ])
            try cache.clear()

            try cache.write(again)

            #expect(try cache.savedRecord() == again)
        }
    }

    @Suite("日付を読めない行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataWeightTrendCache

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataWeightTrendCache(context: context)
            try cache.write(
                WeightTrend(days: [
                    SwiftDataWeightTrendCacheTests.day(20, 72.4),
                    SwiftDataWeightTrendCacheTests.day(21, 72.35),
                ]))
            let rows = try context.fetch(FetchDescriptor<CachedWeightTrendDay>())
            try #require(rows.first { $0.day == "2026-09-21" }).day = "2026/09/21"
            try context.save()
        }

        @Test("読めない行を飛ばし、読める日だけの傾向を読むこと")
        func skipsUnreadableRows() throws {
            #expect(
                try cache.savedRecord()
                    == WeightTrend(days: [SwiftDataWeightTrendCacheTests.day(20, 72.4)]))
        }
    }
}
