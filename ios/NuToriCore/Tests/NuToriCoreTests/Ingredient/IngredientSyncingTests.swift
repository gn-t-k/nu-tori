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

    @Test("サーバーだけが書く種類として、送る書き込みを持たないこと")
    func hasNoWrites() {
        #expect(syncing.writes == nil)
    }

    @Test("栄養の項目の名前を端末の項目に変え、知らない項目は読み飛ばすこと")
    func skipsUnknownNutrients() {
        let synced = SyncedIngredient.fixture(
            nutrients: ["energy_kcal": 204, "protein_g": 16.6, "future_nutrient_g": 1.5])

        let current = syncing.current(from: [.ingredient(synced)])

        #expect(current.ingredients.map(\.nutrients) == [[.energyKcal: 204, .proteinG: 16.6]])
    }

    @Test("出どころと量と親の料理の ID を、そのまま持つこと")
    func keepsFields() throws {
        let synced = SyncedIngredient.fixture(
            nutrientSource: .nutritionLabel(basisGrams: 250), nutrients: [:])

        let ingredient = try #require(
            syncing.current(from: [.ingredient(synced)]).ingredients.first)

        #expect(ingredient.id == Self.ingredientId)
        #expect(ingredient.dishId == Self.dishId)
        #expect(ingredient.name == "鶏もも肉")
        #expect(ingredient.quantity == 80)
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
}

extension SyncedIngredient {
    fileprivate static func fixture(
        nutrientSource: NutrientSource = .foodComposition(foodNumber: "11225"),
        nutrients: [String: Double]
    ) -> SyncedIngredient {
        SyncedIngredient(
            id: IngredientSyncingTests.ingredientId, dishId: IngredientSyncingTests.dishId,
            name: "鶏もも肉", quantity: 80, unit: "g", edibleGramsPerUnit: 1, positionInDish: 3,
            nutrientSource: nutrientSource, nutrients: nutrients)
    }
}

extension SyncedDish {
    fileprivate static func fixture() -> SyncedDish {
        SyncedDish(
            id: IngredientSyncingTests.dishId, mealId: UUID(), name: "親子丼", quantity: 1,
            unit: "杯", positionInMeal: 0, version: 1)
    }
}
