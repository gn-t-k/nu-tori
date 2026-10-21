import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("食事の推定の状態のキャッシュの行")
struct CachedMealEstimationStatusCacheTests {
    typealias Status = MealEstimationStatusSyncing.Status

    /// すべての状態を、食事ごとに1つずつ保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func filledCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedMealEstimationStatus>,
        awaitingPhotos: Status, others: Set<Status>
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedMealEstimationStatus>(
            context: store.container.mainContext)
        let awaitingPhotos = Status(mealId: UUID(), status: .awaitingPhotos)
        let others: Set<Status> = [
            Status(mealId: UUID(), status: .estimating),
            Status(mealId: UUID(), status: .estimated),
            Status(mealId: UUID(), status: .noDishes),
            Status(mealId: UUID(), status: .deferredToNextDay),
            Status(mealId: UUID(), status: .awaitingSubscription),
            Status(mealId: UUID(), status: .failed),
        ]
        try cache.upsert(awaitingPhotos)
        for status in others {
            try cache.upsert(status)
        }
        try cache.context.save()
        return (store, cache, awaitingPhotos, others)
    }

    @Suite("すべての状態を、食事ごとに1つずつ足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedMealEstimationStatus>
        let awaitingPhotos: Status
        let others: Set<Status>

        init() throws {
            (store, cache, awaitingPhotos, others) =
                try CachedMealEstimationStatusCacheTests.filledCache()
        }

        @Test("足した状態と同じ状態を、どの状態でも読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == others.union([awaitingPhotos]))
        }

        @Suite("同じ食事の状態を足すとき")
        @MainActor
        struct UpsertingSameMeal {
            let store: SwiftDataSyncStore
            let cache: SwiftDataKeyedRecordCache<CachedMealEstimationStatus>
            let others: Set<Status>
            let estimating: Status

            init() throws {
                let filled = try CachedMealEstimationStatusCacheTests.filledCache()
                store = filled.store
                cache = filled.cache
                others = filled.others
                estimating = Status(mealId: filled.awaitingPhotos.mealId, status: .estimating)
            }

            @Test("行を増やさず状態が替わること")
            func replaces() throws {
                try cache.upsert(estimating)

                let saved = try cache.savedRecords()
                #expect(saved.count == others.count + 1)
                #expect(Set(saved) == others.union([estimating]))
            }
        }

        @Test("食事の ID で消すと、その食事の状態の行だけが無くなること")
        func removesByMealId() throws {
            try cache.remove(id: awaitingPhotos.mealId)

            #expect(Set(try cache.savedRecords()) == others)
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("知らない状態の行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedMealEstimationStatus>
        let readable: Status

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            readable = Status(mealId: UUID(), status: .estimated)
            let unknown = Status(mealId: UUID(), status: .estimating)
            try cache.upsert(readable)
            try cache.upsert(unknown)
            try #require(try CachedMealEstimationStatus.find(id: unknown.mealId, in: context))
                .status = "reviewing"
            try context.save()
        }

        @Test("読めない行を飛ばし、読める状態だけを読むこと")
        func skipsUnreadableRows() throws {
            #expect(try cache.savedRecords() == [readable])
        }
    }
}
