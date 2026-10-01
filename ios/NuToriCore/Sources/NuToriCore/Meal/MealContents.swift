public import Foundation

/// 食事の料理と材料、栄養の合計。食事の画面とタイムラインのカード、日の丸が使う。
/// 親の食事・料理がまだ届いていない料理と材料は入れない（親が届くまで画面に出さない）
public struct MealContents: Hashable, Sendable {
    /// 食事の中の並び順（同じなら ID の順）
    public let dishes: [DishContents]
    /// 食事の栄養の合計
    public let totals: NutrientTotals
    /// 栄養の出どころの1行。材料が無い食事は nil
    public let nutrientSourceLine: NutrientSourceLine?
    /// 「栄養の出典 ›」の行を置くか。成分表を使った材料が1つでもあるとき
    public let showsNutrientCitation: Bool

    /// カードの名前の場所に置く、料理の名前を並び順に「・」でつないだもの。料理が無ければ nil
    public var name: String? {
        dishes.isEmpty ? nil : dishes.map(\.dish.name).joined(separator: "・")
    }

    /// `dishes` と `ingredients` は、全部の食事・全部の料理のものを渡してよい（この食事のものだけを取り出す）
    public init(mealId: UUID, dishes: [Dish], ingredients: [Ingredient]) {
        let ingredientsByDish = Dictionary(grouping: ingredients, by: \.dishId)
        self.dishes =
            dishes
            .filter { $0.mealId == mealId }
            .sorted {
                ($0.positionInMeal, $0.id.uuidString) < ($1.positionInMeal, $1.id.uuidString)
            }
            .map { DishContents(dish: $0, ingredientsInAnyOrder: ingredientsByDish[$0.id] ?? []) }
        let ingredientsOfMeal = self.dishes.flatMap(\.ingredients)
        totals = NutrientTotals(combining: self.dishes.map(\.totals))
        nutrientSourceLine = NutrientSourceLine(ingredients: ingredientsOfMeal)
        showsNutrientCitation = ingredientsOfMeal.contains {
            $0.nutrientSource.kind == .foodComposition
        }
    }
}
