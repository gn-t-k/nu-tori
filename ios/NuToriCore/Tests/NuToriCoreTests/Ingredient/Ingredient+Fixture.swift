import Foundation
import NuToriCore

extension Ingredient {
    /// 既定は成分表の材料で、量は 100 g（1 単位 = 可食部 1 g の「g」）
    static func fixture(
        id: UUID = UUID(),
        dishId: UUID = UUID(),
        name: String = "鶏もも肉",
        quantity: Double = 100,
        unit: String = "g",
        edibleGramsPerUnit: Double = 1,
        positionInDish: Int = 0,
        nutrientSource: NutrientSource = .foodComposition(foodNumber: "11225"),
        nutrients: [Nutrient: Double] = [:]
    ) -> Ingredient {
        Ingredient(
            id: id,
            dishId: dishId,
            name: name,
            quantity: quantity,
            unit: unit,
            edibleGramsPerUnit: edibleGramsPerUnit,
            positionInDish: positionInDish,
            nutrientSource: nutrientSource,
            nutrients: nutrients
        )
    }
}

extension Dish {
    static func fixture(
        id: UUID = UUID(),
        mealId: UUID = UUID(),
        name: String = "親子丼",
        positionInMeal: Int = 0
    ) -> Dish {
        Dish(
            id: id, mealId: mealId, name: name, quantity: 1, unit: "杯",
            positionInMeal: positionInMeal, version: 1)
    }
}
