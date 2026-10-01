import Foundation

/// 料理と、その材料（並び順）。料理の行に出す栄養の合計を持つ
public struct DishContents: Hashable, Sendable {
    public let dish: Dish
    public let ingredients: [Ingredient]
    public let totals: NutrientTotals

    public init(dish: Dish, ingredients: [Ingredient]) {
        self.dish = dish
        self.ingredients = ingredients
        totals = NutrientTotals(ingredients: ingredients)
    }

    /// 料理の材料を、並び順（同じなら ID の順）に並べて持つ。画面とヘルスケアが、同じ順で足した同じ合計を出すため
    public init(dish: Dish, ingredientsInAnyOrder ingredients: [Ingredient]) {
        self.init(
            dish: dish,
            ingredients: ingredients.sorted {
                ($0.positionInDish, $0.id.uuidString) < ($1.positionInDish, $1.id.uuidString)
            }
        )
    }
}
