import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("食事の推定の状態のキャッシュの行")
struct CachedMealEstimationStatusCacheTests {
    typealias Status = MealEstimationStatusSyncing.Status

    @Suite("すべての状態を、食事ごとに1つずつ足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedMealEstimationStatus>
        let awaitingPhotos: Status
        let others: Set<Status>

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataKeyedRecordCache(context: store.container.mainContext)
            awaitingPhotos = Status(mealId: UUID(), status: .awaitingPhotos)
            others = [
                Status(mealId: UUID(), status: .estimating),
                Status(mealId: UUID(), status: .estimated),
                Status(mealId: UUID(), status: .noDishes),
                Status(mealId: UUID(), status: .deferredToNextDay),
                Status(mealId: UUID(), status: .failed),
            ]
            try cache.upsert(awaitingPhotos)
            for status in others {
                try cache.upsert(status)
            }
            try cache.context.save()
        }

        @Test("足した状態と同じ状態を、どの状態でも読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == others.union([awaitingPhotos]))
        }

        @Test("同じ食事の状態を足すと、行を増やさず状態が替わること")
        func replacesSameMeal() throws {
            let estimating = Status(mealId: awaitingPhotos.mealId, status: .estimating)

            try cache.upsert(estimating)

            let saved = try cache.savedRecords()
            #expect(saved.count == 6)
            #expect(Set(saved) == others.union([estimating]))
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
