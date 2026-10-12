import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("料理のキャッシュの行")
struct CachedDishCacheTests {
    @Suite("量のある料理と、量の無い料理を足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedDish>
        let corrected: Dish
        let added: Dish

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataKeyedRecordCache(context: store.container.mainContext)
            corrected = Dish(
                id: UUID(), mealId: UUID(), name: "親子丼",
                quantity: Dish.Quantity(value: 1.5, unit: "杯", source: .corrected),
                positionInMeal: 0, version: 2)
            added = Dish(
                id: UUID(), mealId: UUID(), name: "味噌汁", quantity: nil, positionInMeal: 1,
                version: 1)
            try cache.upsert(corrected)
            try cache.upsert(added)
            try cache.context.save()
        }

        @Test("足した料理と同じ料理を、量と量の出どころを保って読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [corrected, added])
        }

        @Test("同じ ID の量の無い料理に量が付くと、行を増やさず値が替わること")
        func replacesWithQuantity() throws {
            let estimated = Dish(
                id: added.id, mealId: UUID(), name: "豆腐の味噌汁",
                quantity: Dish.Quantity(value: 1, unit: "椀", source: .estimated),
                positionInMeal: 2, version: 2)

            try cache.upsert(estimated)

            let saved = try cache.savedRecords()
            #expect(saved.count == 2)
            #expect(Set(saved) == [corrected, estimated])
        }

        @Test("同じ ID の量のある料理が量の無い料理で届くと、量が無くなること")
        func replacesWithoutQuantity() throws {
            let withoutQuantity = Dish(
                id: corrected.id, mealId: corrected.mealId, name: "親子丼", quantity: nil,
                positionInMeal: 0, version: 3)

            try cache.upsert(withoutQuantity)

            #expect(Set(try cache.savedRecords()) == [withoutQuantity, added])
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
