import Foundation
import NuToriAPI
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("ヘルスケアに書いた料理の控え")
struct HealthDishWriteStoringTests {
    static let firstDishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!
    static let secondDishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d2")!

    @Suite("控えを書いたとき")
    @MainActor
    struct Marking {
        let store: SwiftDataSyncStore

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            try await store.markDishWrittenToHealth(
                dishId: HealthDishWriteStoringTests.firstDishId, version: 1)
            try await store.markDishWrittenToHealth(
                dishId: HealthDishWriteStoringTests.secondDishId, version: 1)
        }

        @Test("料理の ID ごとの書いた版を読めること")
        func readsVersions() async throws {
            #expect(
                try await store.dishVersionsWrittenToHealth() == [
                    HealthDishWriteStoringTests.firstDishId: 1,
                    HealthDishWriteStoringTests.secondDishId: 1,
                ])
        }

        @Test("同じ料理を書き直すと、版が新しくなること")
        func updatesVersion() async throws {
            try await store.markDishWrittenToHealth(
                dishId: HealthDishWriteStoringTests.firstDishId, version: 2)

            #expect(
                try await store.dishVersionsWrittenToHealth()[
                    HealthDishWriteStoringTests.firstDishId] == 2)
        }

        @Test("控えを消せること")
        func unmarks() async throws {
            try await store.unmarkDishWrittenToHealth(
                dishId: HealthDishWriteStoringTests.firstDishId)

            #expect(
                try await store.dishVersionsWrittenToHealth() == [
                    HealthDishWriteStoringTests.secondDishId: 1
                ])
        }

        @Test("全消去で、控えも無くなること")
        func erasesWithEverythingElse() async throws {
            try await store.eraseAll()

            #expect(try await store.dishVersionsWrittenToHealth().isEmpty)
        }
    }

    @Suite("食事・料理・材料がキャッシュにあるとき")
    @MainActor
    struct ReadingCache {
        let store: SwiftDataSyncStore
        let mealId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .dish,
                        changes: [
                            .dish(
                                SyncedDish(
                                    id: HealthDishWriteStoringTests.firstDishId, mealId: mealId,
                                    name: "親子丼",
                                    quantity: .init(value: 1, unit: "杯", source: .estimated),
                                    positionInMeal: 0, version: 1))
                        ]),
                    KindChanges(
                        kind: .ingredient,
                        changes: [
                            .ingredient(
                                SyncedIngredient(
                                    id: UUID(), dishId: HealthDishWriteStoringTests.firstDishId,
                                    name: "鶏もも肉", quantity: 80, quantitySource: .estimated,
                                    unit: "g",
                                    edibleGramsPerUnit: 1, positionInDish: 0,
                                    nutrientSource: .estimated, nutrients: ["energy_kcal": 204]))
                        ]),
                ]))
        }

        @Test("親の食事が無くても、料理と材料を読めること")
        func readsDishesAndIngredients() async throws {
            #expect(try await store.meals().isEmpty)
            #expect(try await store.dishes().map(\.id) == [HealthDishWriteStoringTests.firstDishId])
            #expect(
                try await store.ingredients().map(\.dishId) == [
                    HealthDishWriteStoringTests.firstDishId
                ])
        }
    }
}
