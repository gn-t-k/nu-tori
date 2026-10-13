import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("材料の同期")
struct IngredientSyncingTests {
    static let ingredientId = UUID(uuidString: "00000000-0000-4000-8000-0000000000e1")!
    static let dishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!

    let syncing = IngredientSyncing()

    @Test("材料と材料の削除の印だけを、この種類の変更として見分けること")
    func ownsOnlyIngredientChanges() {
        let synced = SyncedIngredient.fixture(nutrients: [:])

        #expect(syncing.owns(.ingredient(synced)))
        #expect(syncing.owns(.ingredientDeletion(ingredientId: Self.ingredientId)))
        #expect(!syncing.owns(.dish(.fixture())))
        #expect(!syncing.owns(.unknown(kind: "ingredient")))
    }

    @Test("端末も書く種類として、送る書き込みを持つこと")
    func hasWrites() {
        #expect(syncing.writes != nil)
    }

    @Test("栄養の項目の名前を端末の項目に変え、知らない項目は読み飛ばすこと")
    func skipsUnknownNutrients() {
        let synced = SyncedIngredient.fixture(
            nutrients: ["energy_kcal": 204, "protein_g": 16.6, "future_nutrient_g": 1.5])

        let current = syncing.current(from: [.ingredient(synced)])

        #expect(current.ingredients.map(\.nutrients) == [[.energyKcal: 204, .proteinG: 16.6]])
    }

    @Test("出どころと量と量の出どころと親の料理の ID を、そのまま持つこと")
    func keepsFields() throws {
        let synced = SyncedIngredient.fixture(
            nutrientSource: .nutritionLabel(basisGrams: 250), nutrients: [:])

        let ingredient = try #require(
            syncing.current(from: [.ingredient(synced)]).ingredients.first)

        #expect(ingredient.id == Self.ingredientId)
        #expect(ingredient.dishId == Self.dishId)
        #expect(ingredient.name == "鶏もも肉")
        #expect(ingredient.quantity == 80)
        #expect(ingredient.quantitySource == .corrected)
        #expect(ingredient.unit == "g")
        #expect(ingredient.edibleGramsPerUnit == 1)
        #expect(ingredient.positionInDish == 3)
        #expect(ingredient.nutrientSource == .nutritionLabel(basisGrams: 250))
    }

    @Test("削除の印の材料の ID を、届いた順に返すこと")
    func returnsRemovedIds() {
        let other = UUID()

        let current = syncing.current(from: [
            .ingredientDeletion(ingredientId: Self.ingredientId),
            .ingredientDeletion(ingredientId: other),
            .dishDeletion(dishId: Self.dishId),
        ])

        #expect(current.removedIngredientIds == [Self.ingredientId, other])
    }

    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = IngredientSyncing()
        let cache: MemoryKeyedRecordCache<Ingredient, UUID>
        let kept: Ingredient
        let removed: Ingredient

        init() throws {
            (cache, kept, removed) = try Self.appliedCache()
        }

        /// 材料を2件当てたキャッシュ。親の料理は届いていない
        static func appliedCache() throws -> (
            cache: MemoryKeyedRecordCache<Ingredient, UUID>, kept: Ingredient, removed: Ingredient
        ) {
            let cache = MemoryKeyedRecordCache<Ingredient, UUID>(id: \.id)
            let kept = Ingredient.fixture(name: "鶏もも肉", nutrients: [.energyKcal: 204])
            let removed = Ingredient.fixture(
                name: "ご飯", positionInDish: 1, nutrientSource: .estimated)
            try IngredientSyncing().apply(
                [kept, removed].map { .ingredient(synced($0)) }, to: cache)
            return (cache, kept, removed)
        }

        static func synced(_ ingredient: Ingredient) -> SyncedIngredient {
            let nutrientSource: SyncedIngredient.NutrientSource =
                switch ingredient.nutrientSource {
                case .nutritionLabel(let basisGrams): .nutritionLabel(basisGrams: basisGrams)
                case .foodComposition(let foodNumber): .foodComposition(foodNumber: foodNumber)
                case .estimated: .estimated
                }
            return SyncedIngredient(
                id: ingredient.id, dishId: ingredient.dishId, name: ingredient.name,
                quantity: ingredient.quantity,
                quantitySource: ingredient.quantitySource == .corrected ? .corrected : .estimated,
                unit: ingredient.unit, edibleGramsPerUnit: ingredient.edibleGramsPerUnit,
                positionInDish: ingredient.positionInDish, nutrientSource: nutrientSource,
                nutrients: Dictionary(
                    uniqueKeysWithValues: ingredient.nutrients.map { ($0.key.rawValue, $0.value) }))
        }

        @Test("親の料理が無くても、届いた材料が今の値でキャッシュに入ること")
        func storesArrivedIngredients() {
            #expect(Set(cache.all()) == [kept, removed])
        }

        @Suite("同じ材料が届き直したとき")
        struct ArrivedAgain {
            let syncing = IngredientSyncing()
            let cache: MemoryKeyedRecordCache<Ingredient, UUID>
            let removed: Ingredient
            let corrected: Ingredient

            init() throws {
                let applied = try Applying.appliedCache()
                cache = applied.cache
                removed = applied.removed
                corrected = Ingredient.fixture(
                    id: applied.kept.id, dishId: applied.kept.dishId, quantity: 150,
                    quantitySource: .corrected, nutrients: [.energyKcal: 306])
            }

            @Test("キャッシュの材料をその値にそろえること")
            func overwritesWithArrivedValue() throws {
                try syncing.apply([.ingredient(Applying.synced(corrected))], to: cache)

                #expect(Set(cache.all()) == [corrected, removed])
            }
        }

        @Test("削除の印の材料が消え、キャッシュに無い材料の削除の印は読み飛ばすこと")
        func removesMarkedIngredientsAndSkipsMissing() throws {
            try syncing.apply(
                [
                    .ingredientDeletion(ingredientId: removed.id),
                    .ingredientDeletion(ingredientId: UUID()),
                ], to: cache)

            #expect(cache.all() == [kept])
        }

        @Test("同じ材料の今の値と削除の印が一緒に届いたら、消えていること")
        func removalWinsOverValueInSameChanges() throws {
            try syncing.apply(
                [.ingredientDeletion(ingredientId: kept.id), .ingredient(Self.synced(kept))],
                to: cache)

            #expect(cache.all() == [removed])
        }

        @Test("ほかの種類の変更は、キャッシュを変えないこと")
        func skipsOtherKinds() throws {
            try syncing.apply([.dishDeletion(dishId: kept.id)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、材料がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}

extension SyncedIngredient {
    fileprivate static func fixture(
        nutrientSource: NutrientSource = .foodComposition(foodNumber: "11225"),
        nutrients: [String: Double]
    ) -> SyncedIngredient {
        SyncedIngredient(
            id: IngredientSyncingTests.ingredientId, dishId: IngredientSyncingTests.dishId,
            name: "鶏もも肉", quantity: 80, quantitySource: .corrected, unit: "g",
            edibleGramsPerUnit: 1, positionInDish: 3,
            nutrientSource: nutrientSource, nutrients: nutrients)
    }
}

extension SyncedDish {
    fileprivate static func fixture() -> SyncedDish {
        SyncedDish(
            id: IngredientSyncingTests.dishId, mealId: UUID(), name: "親子丼",
            quantity: .init(value: 1, unit: "杯", source: .estimated), positionInMeal: 0,
            version: 1)
    }
}
