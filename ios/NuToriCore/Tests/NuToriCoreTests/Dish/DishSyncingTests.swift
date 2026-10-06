import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("料理の同期")
struct DishSyncingTests {
    static let dishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!
    static let mealId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!

    let syncing = DishSyncing()

    @Test("料理と料理の削除の印だけを、この種類の変更として見分けること")
    func ownsOnlyDishChanges() {
        #expect(syncing.owns(.dish(Self.synced)))
        #expect(syncing.owns(.dishDeletion(dishId: Self.dishId)))
        #expect(!syncing.owns(.ingredientDeletion(ingredientId: Self.dishId)))
        #expect(!syncing.owns(.unknown(kind: "dish")))
    }

    @Test("端末も書く種類として、送る書き込みを持つこと")
    func hasWrites() {
        #expect(syncing.writes != nil)
    }

    @Test("量の無い料理は、量を持たないこと")
    func keepsNoQuantity() throws {
        let dish = try #require(
            syncing.current(from: [
                .dish(
                    SyncedDish(
                        id: Self.dishId, mealId: Self.mealId, name: "味噌汁", quantity: nil,
                        positionInMeal: 3, version: 1))
            ]).dishes.first)

        #expect(dish.quantity == nil)
    }

    @Test("料理の名前・量と単位と出どころ・並び順・版と、親の食事の ID をそのまま持つこと")
    func keepsFields() throws {
        let dish = try #require(syncing.current(from: [.dish(Self.synced)]).dishes.first)

        #expect(dish.id == Self.dishId)
        #expect(dish.mealId == Self.mealId)
        #expect(dish.name == "親子丼")
        #expect(dish.quantity == Dish.Quantity(value: 1.5, unit: "杯", source: .corrected))
        #expect(dish.positionInMeal == 2)
        #expect(dish.version == 1)
    }

    @Test("削除の印の料理の ID を、届いた順に返すこと")
    func returnsRemovedIds() {
        let other = UUID()

        let current = syncing.current(from: [
            .dishDeletion(dishId: Self.dishId), .dishDeletion(dishId: other),
        ])

        #expect(current.removedDishIds == [Self.dishId, other])
    }

    static let synced = SyncedDish(
        id: dishId, mealId: mealId, name: "親子丼",
        quantity: .init(value: 1.5, unit: "杯", source: .corrected), positionInMeal: 2, version: 1)
}
