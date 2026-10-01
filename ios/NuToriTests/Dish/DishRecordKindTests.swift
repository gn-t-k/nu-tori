import Foundation
import NuToriAPI
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("料理と材料の種類")
struct DishRecordKindTests {
    static let keptDishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!
    static let removedDishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d2")!
    static let keptIngredientId = UUID(uuidString: "00000000-0000-4000-8000-0000000000e1")!
    static let removedIngredientId = UUID(uuidString: "00000000-0000-4000-8000-0000000000e2")!

    static func syncedDish(id: UUID) -> SyncedDish {
        SyncedDish(
            id: id, mealId: UUID(), name: "親子丼", quantity: 1, unit: "杯", positionInMeal: 0,
            version: 1)
    }

    static func syncedIngredient(
        id: UUID, nutrientSource: SyncedIngredient.NutrientSource
    ) -> SyncedIngredient {
        SyncedIngredient(
            id: id, dishId: keptDishId, name: "鶏もも肉", quantity: 80, unit: "g",
            edibleGramsPerUnit: 1, positionInDish: 0, nutrientSource: nutrientSource,
            nutrients: ["energy_kcal": 204, "protein_g": 16.6, "future_nutrient_g": 1.5])
    }

    @Suite("取りに行った料理と材料をキャッシュに当てるとき")
    @MainActor
    struct Applying {
        let store: SwiftDataSyncStore

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            // 親の食事も、材料の親の料理（DishRecordKindTests.removedDishId）も届いていない
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .dish,
                        changes: [
                            .dish(DishRecordKindTests.syncedDish(id: DishRecordKindTests.keptDishId)),
                            .dish(
                                DishRecordKindTests.syncedDish(
                                    id: DishRecordKindTests.removedDishId)),
                        ]),
                    KindChanges(
                        kind: .ingredient,
                        changes: [
                            .ingredient(
                                DishRecordKindTests.syncedIngredient(
                                    id: DishRecordKindTests.keptIngredientId,
                                    nutrientSource: .foodComposition(foodNumber: "11225"))),
                            .ingredient(
                                DishRecordKindTests.syncedIngredient(
                                    id: DishRecordKindTests.removedIngredientId,
                                    nutrientSource: .nutritionLabel(basisGrams: 250))),
                        ]),
                ]))
        }

        @Test("親の食事が無くても、料理がキャッシュに入ること")
        func storesDishes() throws {
            let dishes = try store.container.mainContext.fetch(FetchDescriptor<CachedDish>())

            #expect(Set(dishes.map(\.dishId)) == [DishRecordKindTests.keptDishId, DishRecordKindTests.removedDishId])
        }

        @Test("知らない栄養の項目を読み飛ばし、出どころと栄養の値を保って材料がキャッシュに入ること")
        func storesIngredients() throws {
            let ingredients = try store.container.mainContext.fetch(
                FetchDescriptor<CachedIngredient>()
            )
            .compactMap { $0.ingredient() }

            let kept = try #require(ingredients.first { $0.id == DishRecordKindTests.keptIngredientId })
            let labeled = try #require(ingredients.first { $0.id == DishRecordKindTests.removedIngredientId })
            #expect(kept.nutrientSource == .foodComposition(foodNumber: "11225"))
            #expect(kept.nutrients == [.energyKcal: 204, .proteinG: 16.6])
            #expect(labeled.nutrientSource == .nutritionLabel(basisGrams: 250))
        }

        @Test("削除の印の料理と材料が消えること")
        func removesDeleted() async throws {
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(kind: .dish, changes: [.dishDeletion(dishId: DishRecordKindTests.removedDishId)]),
                    KindChanges(
                        kind: .ingredient,
                        changes: [.ingredientDeletion(ingredientId: DishRecordKindTests.removedIngredientId)]),
                ]))

            let dishes = try store.container.mainContext.fetch(FetchDescriptor<CachedDish>())
            let ingredients = try store.container.mainContext.fetch(
                FetchDescriptor<CachedIngredient>())
            #expect(dishes.map(\.dishId) == [DishRecordKindTests.keptDishId])
            #expect(ingredients.map(\.ingredientId) == [DishRecordKindTests.keptIngredientId])
        }

        @Test("全消去で、料理と材料がキャッシュから無くなること")
        func erasesWithEverythingElse() async throws {
            try await store.eraseAll()

            #expect(try store.container.mainContext.fetch(FetchDescriptor<CachedDish>()).isEmpty)
            #expect(
                try store.container.mainContext.fetch(FetchDescriptor<CachedIngredient>()).isEmpty)
        }
    }
}
