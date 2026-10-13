import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("料理ごとの推定の状態のキャッシュの行")
struct CachedDishEstimationStatusCacheTests {
    typealias Status = DishEstimationStatusSyncing.Status

    /// すべての状態を、料理ごとに1つずつ保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func filledCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedDishEstimationStatus>,
        estimating: Status, others: Set<Status>
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedDishEstimationStatus>(
            context: store.container.mainContext)
        let estimating = Status(dishId: UUID(), status: .estimating)
        let others: Set<Status> = [
            Status(dishId: UUID(), status: .deferredToNextDay),
            Status(dishId: UUID(), status: .estimated),
            Status(dishId: UUID(), status: .noDishes),
            Status(dishId: UUID(), status: .failed),
        ]
        try cache.upsert(estimating)
        for status in others {
            try cache.upsert(status)
        }
        try cache.context.save()
        return (store, cache, estimating, others)
    }

    @Suite("すべての状態を、料理ごとに1つずつ足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedDishEstimationStatus>
        let estimating: Status
        let others: Set<Status>

        init() throws {
            (store, cache, estimating, others) =
                try CachedDishEstimationStatusCacheTests.filledCache()
        }

        @Test("足した状態と同じ状態を、どの状態でも読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == others.union([estimating]))
        }

        @Suite("同じ料理の状態を足すとき")
        @MainActor
        struct UpsertingSameDish {
            let store: SwiftDataSyncStore
            let cache: SwiftDataKeyedRecordCache<CachedDishEstimationStatus>
            let others: Set<Status>
            let estimated: Status

            init() throws {
                let filled = try CachedDishEstimationStatusCacheTests.filledCache()
                store = filled.store
                cache = filled.cache
                others = filled.others
                estimated = Status(dishId: filled.estimating.dishId, status: .estimated)
            }

            @Test("行を増やさず状態が替わること")
            func replaces() throws {
                try cache.upsert(estimated)

                let saved = try cache.savedRecords()
                #expect(saved.count == 5)
                #expect(Set(saved) == others.union([estimated]))
            }
        }

        @Test("料理の ID で消すと、その料理の状態の行だけが無くなること")
        func removesByDishId() throws {
            try cache.remove(id: estimating.dishId)

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
        let cache: SwiftDataKeyedRecordCache<CachedDishEstimationStatus>
        let readable: Status

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            readable = Status(dishId: UUID(), status: .estimated)
            let unknown = Status(dishId: UUID(), status: .estimating)
            try cache.upsert(readable)
            try cache.upsert(unknown)
            try #require(try CachedDishEstimationStatus.find(id: unknown.dishId, in: context))
                .status = "reviewing"
            try context.save()
        }

        @Test("読めない行を飛ばし、読める状態だけを読むこと")
        func skipsUnreadableRows() throws {
            #expect(try cache.savedRecords() == [readable])
        }
    }
}
