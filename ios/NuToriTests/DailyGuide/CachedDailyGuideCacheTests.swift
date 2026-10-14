import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("1日の目安のキャッシュの行")
struct CachedDailyGuideCacheTests {
    static func guide(
        id: UUID = UUID(), day: Int, energyKilocalories: Int = 1850,
        limitHits: [DailyGuide.LimitHit] = []
    ) -> DailyGuide {
        DailyGuide(
            id: id, goalId: UUID(), expenditureEstimateId: UUID(),
            effectiveDay: CalendarDay(year: 2026, month: 10, day: day),
            energyKilocalories: energyKilocalories, proteinGrams: 130, fatGrams: 50,
            carbohydrateGrams: 220, limitHits: limitHits)
    }

    /// 上限と下限に当たった1日の目安と、当たっていない1日の目安を保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく。
    /// どちらの目標も推定消費カロリーも、キャッシュに無い
    @MainActor static func filledCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedDailyGuide>,
        limited: DailyGuide, plain: DailyGuide
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedDailyGuide>(
            context: store.container.mainContext)
        // 並びは区分の名前の順と逆にして、並び順を保つことを確かめる
        let limited = guide(
            day: 1, energyKilocalories: 1200,
            limitHits: [.weeklyChange, .requiredPace, .minimumEnergy])
        let plain = guide(day: 8)
        try cache.upsert(limited)
        try cache.upsert(plain)
        try cache.context.save()
        return (store, cache, limited, plain)
    }

    @Suite("目標が届いていない1日の目安を足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedDailyGuide>
        let limited: DailyGuide
        let plain: DailyGuide

        init() throws {
            (store, cache, limited, plain) = try CachedDailyGuideCacheTests.filledCache()
        }

        @Test("足した1日の目安と同じものを、目標の ID と当たった上限・下限の並びを保って読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [limited, plain])
        }

        @Test("同じ ID の1日の目安を足すと、行を増やさず値が替わること")
        func replaces() throws {
            let revised = CachedDailyGuideCacheTests.guide(
                id: limited.id, day: 2, energyKilocalories: 1900)

            try cache.upsert(revised)

            let saved = try cache.savedRecords()
            #expect(saved.count == 2)
            #expect(Set(saved) == [revised, plain])
        }

        @Test("ID で消すと、その1日の目安の行だけが無くなること")
        func removesById() throws {
            try cache.remove(id: limited.id)

            #expect(try cache.savedRecords() == [plain])
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("当てる始まりの日が読めない行と、知らない上限を持つ行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedDailyGuide>
        let withUnknownLimit: DailyGuide

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            withUnknownLimit = CachedDailyGuideCacheTests.guide(
                day: 1, limitHits: [.minimumEnergy])
            let unreadableDay = CachedDailyGuideCacheTests.guide(day: 8)
            try cache.upsert(withUnknownLimit)
            try cache.upsert(unreadableDay)
            try #require(try CachedDailyGuide.find(id: withUnknownLimit.id, in: context))
                .limitHits = ["limit_added_later", "minimum_energy"]
            try #require(try CachedDailyGuide.find(id: unreadableDay.id, in: context))
                .effectiveDay = "10月8日"
            try context.save()
        }

        @Test("日付が読めない行を飛ばし、知らない上限は外して目安を読むこと")
        func skipsUnreadableDayAndDropsUnknownLimit() throws {
            #expect(try cache.savedRecords() == [withUnknownLimit])
        }
    }
}
