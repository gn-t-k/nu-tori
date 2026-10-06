import Foundation
import NuToriCore
import Testing

@Suite("料理を消すときの、最後の1品の数え方")
struct DishRemovalTests {
    static let mealId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!
    static let estimatedDishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!
    static let addedDishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d2")!

    @Suite("食事に、推定できた料理と、足したばかりで量の無い料理があるとき")
    struct WithAddedDish {
        let dishes: [Dish]

        init() {
            dishes = [
                .fixture(id: DishRemovalTests.estimatedDishId, mealId: DishRemovalTests.mealId),
                .fixture(
                    id: DishRemovalTests.addedDishId, mealId: DishRemovalTests.mealId,
                    name: "味噌汁", quantity: nil, positionInMeal: 1),
                .fixture(mealId: UUID(), name: "ほかの食事の料理"),
            ]
        }

        @Test("推定できた料理は、最後の1品でないこと")
        func estimatedDishIsNotLast() {
            #expect(
                DishRemoval(removing: DishRemovalTests.estimatedDishId, among: dishes)
                    == .dish(dishId: DishRemovalTests.estimatedDishId))
        }

        @Test("足したばかりの料理も1品に数え、最後の1品でないこと")
        func addedDishIsNotLast() {
            #expect(
                DishRemoval(removing: DishRemovalTests.addedDishId, among: dishes)
                    == .dish(dishId: DishRemovalTests.addedDishId))
        }
    }

    @Suite("食事に、推定し直しが通らなかった料理だけがあるとき")
    struct WithOnlyFailedDish {
        let dishes: [Dish]

        init() {
            // 通らなかった料理は、名前と前の量を残し、材料を持たない
            dishes = [
                .fixture(id: DishRemovalTests.estimatedDishId, mealId: DishRemovalTests.mealId),
                .fixture(mealId: UUID(), name: "ほかの食事の料理"),
            ]
        }

        @Test("最後の1品として、食事ごと消すこと")
        func removesMeal() {
            #expect(
                DishRemoval(removing: DishRemovalTests.estimatedDishId, among: dishes)
                    == .meal(mealId: DishRemovalTests.mealId))
        }
    }
}
