import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("料理のキャッシュの行")
struct CachedDishCacheTests {
    /// 量のある料理と、量の無い料理を保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func filledCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedDish>, corrected: Dish,
        added: Dish
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedDish>(context: store.container.mainContext)
        let corrected = Dish(
            id: UUID(), mealId: UUID(), name: "親子丼",
            quantity: Dish.Quantity(value: 1.5, unit: "杯", source: .corrected),
            positionInMeal: 0, version: 2)
        let added = Dish(
            id: UUID(), mealId: UUID(), name: "味噌汁", quantity: nil, positionInMeal: 1,
            version: 1)
        try cache.upsert(corrected)
        try cache.upsert(added)
        try cache.context.save()
        return (store, cache, corrected, added)
    }

    @Suite("量のある料理と、量の無い料理を足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedDish>
        let corrected: Dish
        let added: Dish

        init() throws {
            (store, cache, corrected, added) = try CachedDishCacheTests.filledCache()
        }

        @Test("足した料理と同じ料理を、量と量の出どころを保って読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [corrected, added])
        }

        @Suite("量の無い料理と同じ ID の、量の付いた料理を足すとき")
        @MainActor
        struct UpsertingWithQuantity {
            let store: SwiftDataSyncStore
            let cache: SwiftDataKeyedRecordCache<CachedDish>
            let corrected: Dish
            let estimated: Dish

            init() throws {
                let filled = try CachedDishCacheTests.filledCache()
                store = filled.store
                cache = filled.cache
                corrected = filled.corrected
                estimated = Dish(
                    id: filled.added.id, mealId: UUID(), name: "豆腐の味噌汁",
                    quantity: Dish.Quantity(value: 1, unit: "椀", source: .estimated),
                    positionInMeal: 2, version: 2)
            }

            @Test("行を増やさず値が替わること")
            func replaces() throws {
                try cache.upsert(estimated)

                let saved = try cache.savedRecords()
                #expect(saved.count == 2)
                #expect(Set(saved) == [corrected, estimated])
            }
        }

        @Suite("量のある料理と同じ ID の、量の無い料理を足すとき")
        @MainActor
        struct UpsertingWithoutQuantity {
            let store: SwiftDataSyncStore
            let cache: SwiftDataKeyedRecordCache<CachedDish>
            let added: Dish
            let withoutQuantity: Dish

            init() throws {
                let filled = try CachedDishCacheTests.filledCache()
                store = filled.store
                cache = filled.cache
                added = filled.added
                withoutQuantity = Dish(
                    id: filled.corrected.id, mealId: filled.corrected.mealId, name: "親子丼",
                    quantity: nil, positionInMeal: 0, version: 3)
            }

            @Test("量が無くなること")
            func losesQuantity() throws {
                try cache.upsert(withoutQuantity)

                #expect(Set(try cache.savedRecords()) == [withoutQuantity, added])
            }
        }

        @Test("ID で消すと、その料理の行だけが無くなること")
        func removesById() throws {
            try cache.remove(id: added.id)

            #expect(try cache.savedRecords() == [corrected])
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("量の出どころを読めない行があるとき")
    @MainActor
    struct UnreadableQuantity {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedDish>
        let dish: Dish

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            dish = Dish(
                id: UUID(), mealId: UUID(), name: "親子丼",
                quantity: Dish.Quantity(value: 1, unit: "杯", source: .estimated),
                positionInMeal: 0, version: 1)
            try cache.upsert(dish)
            try #require(try CachedDish.find(id: dish.id, in: context)).quantitySource = "weighed"
            try context.save()
        }

        @Test("行を飛ばさず、量の無い料理として読むこと")
        func readsAsDishWithoutQuantity() throws {
            #expect(
                try cache.savedRecords() == [
                    Dish(
                        id: dish.id, mealId: dish.mealId, name: "親子丼", quantity: nil,
                        positionInMeal: 0, version: 1)
                ])
        }
    }
}
