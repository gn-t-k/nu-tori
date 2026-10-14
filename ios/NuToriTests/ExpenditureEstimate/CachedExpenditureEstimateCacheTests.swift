import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("推定消費カロリーのキャッシュの行")
struct CachedExpenditureEstimateCacheTests {
    static func estimate(
        id: UUID = UUID(), day: Int, expenditureKilocalories: Int = 2300,
        initialSource: ExpenditureEstimate.InitialSource?
    ) -> ExpenditureEstimate {
        ExpenditureEstimate(
            id: id, effectiveDay: CalendarDay(year: 2026, month: 10, day: day),
            expenditureKilocalories: expenditureKilocalories,
            estimatedAt: Date(timeIntervalSince1970: 1_790_812_800), initialSource: initialSource)
    }

    /// 推定の始まり（逆算）と、そのあとの推定を保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func filledCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedExpenditureEstimate>,
        initial: ExpenditureEstimate, later: ExpenditureEstimate
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedExpenditureEstimate>(
            context: store.container.mainContext)
        let initial = estimate(day: 1, initialSource: .backCalculated)
        let later = estimate(day: 8, expenditureKilocalories: 2250, initialSource: nil)
        try cache.upsert(initial)
        try cache.upsert(later)
        try cache.context.save()
        return (store, cache, initial, later)
    }

    @Suite("推定の始まりと、そのあとの推定を足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedExpenditureEstimate>
        let initial: ExpenditureEstimate
        let later: ExpenditureEstimate

        init() throws {
            (store, cache, initial, later) = try CachedExpenditureEstimateCacheTests.filledCache()
        }

        @Test("足した推定と同じ推定を、出どころの有無を保って読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [initial, later])
        }

        @Test("同じ ID の推定を足すと、行を増やさず値が替わること")
        func replaces() throws {
            let revised = CachedExpenditureEstimateCacheTests.estimate(
                id: initial.id, day: 2, expenditureKilocalories: 2400, initialSource: .formula)

            try cache.upsert(revised)

            let saved = try cache.savedRecords()
            #expect(saved.count == 2)
            #expect(Set(saved) == [revised, later])
        }

        @Test("ID で消すと、その推定の行だけが無くなること")
        func removesById() throws {
            try cache.remove(id: initial.id)

            #expect(try cache.savedRecords() == [later])
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("当てる始まりの日が読めない行と、知らない出どころの行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedExpenditureEstimate>
        let readable: ExpenditureEstimate

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            readable = CachedExpenditureEstimateCacheTests.estimate(day: 1, initialSource: nil)
            let unreadableDay = CachedExpenditureEstimateCacheTests.estimate(
                day: 8, initialSource: nil)
            let unknownSource = CachedExpenditureEstimateCacheTests.estimate(
                day: 15, initialSource: .formula)
            for estimate in [readable, unreadableDay, unknownSource] {
                try cache.upsert(estimate)
            }
            try #require(try CachedExpenditureEstimate.find(id: unreadableDay.id, in: context))
                .effectiveDay = "10月8日"
            try #require(try CachedExpenditureEstimate.find(id: unknownSource.id, in: context))
                .initialSource = "wearable"
            try context.save()
        }

        @Test("読めない行を飛ばし、読める推定だけを読むこと")
        func skipsUnreadableRows() throws {
            #expect(try cache.savedRecords() == [readable])
        }
    }
}
