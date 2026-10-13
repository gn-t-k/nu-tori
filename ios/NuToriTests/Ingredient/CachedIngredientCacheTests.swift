import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("材料のキャッシュの行")
struct CachedIngredientCacheTests {
    static func ingredient(
        id: UUID, nutrientSource: NutrientSource, nutrients: [Nutrient: Double]
    ) -> Ingredient {
        Ingredient(
            id: id, dishId: UUID(), name: "鶏もも肉", quantity: 80, quantitySource: .estimated,
            unit: "g", edibleGramsPerUnit: 1, positionInDish: 0, nutrientSource: nutrientSource,
            nutrients: nutrients)
    }

    /// 栄養の出どころが、栄養成分表示・食品成分表・推定の材料を保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func filledCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedIngredient>,
        labeled: Ingredient, composed: Ingredient, estimated: Ingredient
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedIngredient>(
            context: store.container.mainContext)
        let labeled = ingredient(
            id: UUID(), nutrientSource: .nutritionLabel(basisGrams: 250),
            nutrients: [.energyKcal: 120, .proteinG: 6.5, .fatG: 4.2])
        let composed = ingredient(
            id: UUID(), nutrientSource: .foodComposition(foodNumber: "11225"),
            nutrients: [.energyKcal: 204, .proteinG: 16.6])
        let estimated = Ingredient(
            id: UUID(), dishId: UUID(), name: "ご飯", quantity: 1.5, quantitySource: .corrected,
            unit: "膳", edibleGramsPerUnit: 150, positionInDish: 2, nutrientSource: .estimated,
            nutrients: [:])
        try cache.upsert(labeled)
        try cache.upsert(composed)
        try cache.upsert(estimated)
        try cache.context.save()
        return (store, cache, labeled, composed, estimated)
    }

    @Suite("栄養の出どころが、栄養成分表示・食品成分表・推定の材料を足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedIngredient>
        let labeled: Ingredient
        let composed: Ingredient
        let estimated: Ingredient

        init() throws {
            (store, cache, labeled, composed, estimated) =
                try CachedIngredientCacheTests.filledCache()
        }

        @Test("足した材料と同じ材料を、栄養の出どころと栄養の値を保って読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [labeled, composed, estimated])
        }

        @Suite("同じ ID の材料を足すとき")
        @MainActor
        struct UpsertingSameId {
            let store: SwiftDataSyncStore
            let cache: SwiftDataKeyedRecordCache<CachedIngredient>
            let composed: Ingredient
            let estimated: Ingredient
            let revised: Ingredient

            init() throws {
                let filled = try CachedIngredientCacheTests.filledCache()
                store = filled.store
                cache = filled.cache
                composed = filled.composed
                estimated = filled.estimated
                revised = Ingredient(
                    id: filled.labeled.id, dishId: UUID(), name: "牛乳", quantity: 0.8,
                    quantitySource: .corrected, unit: "杯", edibleGramsPerUnit: 200,
                    positionInDish: 3, nutrientSource: .foodComposition(foodNumber: "13003"),
                    nutrients: [.calciumMg: 110])
            }

            @Test("行を増やさず、栄養の出どころと栄養の値も含めて値が替わること")
            func replaces() throws {
                try cache.upsert(revised)

                let saved = try cache.savedRecords()
                #expect(saved.count == 3)
                #expect(Set(saved) == [revised, composed, estimated])
            }
        }

        @Test("ID で消すと、その材料の行だけが無くなること")
        func removesById() throws {
            try cache.remove(id: composed.id)

            #expect(Set(try cache.savedRecords()) == [labeled, estimated])
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("読めない行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedIngredient>
        let readable: Ingredient
        let withUnknownNutrient: Ingredient

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            readable = CachedIngredientCacheTests.ingredient(
                id: UUID(), nutrientSource: .estimated, nutrients: [.energyKcal: 204])
            withUnknownNutrient = CachedIngredientCacheTests.ingredient(
                id: UUID(), nutrientSource: .estimated, nutrients: [.energyKcal: 204])
            let unknownSource = CachedIngredientCacheTests.ingredient(
                id: UUID(), nutrientSource: .estimated, nutrients: [:])
            let labelWithoutBasis = CachedIngredientCacheTests.ingredient(
                id: UUID(), nutrientSource: .nutritionLabel(basisGrams: 100), nutrients: [:])
            let unknownQuantitySource = CachedIngredientCacheTests.ingredient(
                id: UUID(), nutrientSource: .estimated, nutrients: [:])
            for ingredient in [
                readable, withUnknownNutrient, unknownSource, labelWithoutBasis,
                unknownQuantitySource,
            ] {
                try cache.upsert(ingredient)
            }
            let unknownNutrientRow = try #require(
                try CachedIngredient.find(id: withUnknownNutrient.id, in: context))
            unknownNutrientRow.nutrientNames = ["energy_kcal", "future_nutrient_g"]
            unknownNutrientRow.nutrientValues = [204, 1.5]
            try #require(try CachedIngredient.find(id: unknownSource.id, in: context))
                .sourceType = "measured"
            try #require(try CachedIngredient.find(id: labelWithoutBasis.id, in: context))
                .labelBasisGrams = nil
            try #require(try CachedIngredient.find(id: unknownQuantitySource.id, in: context))
                .quantitySource = "weighed"
            try context.save()
        }

        @Test("栄養の出どころか量の出どころを読めない行を飛ばし、知らない栄養の項目は項目だけを読み飛ばすこと")
        func skipsUnreadableRowsAndUnknownNutrients() throws {
            #expect(Set(try cache.savedRecords()) == [readable, withUnknownNutrient])
        }
    }
}
