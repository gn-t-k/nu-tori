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

    /// `dishes` と `ingredients` は、全部の食事・全部の料理のものを渡してよい（この食事のものだけを取り出す）
    public init(mealId: UUID, dishes: [Dish], ingredients: [Ingredient]) {
        let ingredientsByDish = Dictionary(grouping: ingredients, by: \.dishId)
        self.dishes =
            dishes
            .filter { $0.mealId == mealId }
            .sorted {
                ($0.positionInMeal, $0.id.uuidString) < ($1.positionInMeal, $1.id.uuidString)
            }
            .map { dish in
                DishContents(
                    dish: dish,
                    ingredients: (ingredientsByDish[dish.id] ?? []).sorted {
                        ($0.positionInDish, $0.id.uuidString) < (
                            $1.positionInDish, $1.id.uuidString
                        )
                    }
                )
            }
        let ingredientsOfMeal = self.dishes.flatMap(\.ingredients)
        totals = NutrientTotals(combining: self.dishes.map(\.totals))
        nutrientSourceLine = NutrientSourceLine(ingredients: ingredientsOfMeal)
        showsNutrientCitation = ingredientsOfMeal.contains {
            $0.nutrientSource.kind == .foodComposition
        }
    }
}

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
}

/// 栄養の出どころの1行の値。材料の数を、栄養成分表示・成分表・推定の順に並べ、0 のものは入れない。
/// 文言（「栄養の出どころ: 成分表 4・推定 1」）は画面が組む
public struct NutrientSourceLine: Hashable, Sendable {
    public let entries: [Entry]

    public struct Entry: Hashable, Sendable {
        public let kind: NutrientSource.Kind
        public let count: Int

        public init(kind: NutrientSource.Kind, count: Int) {
            self.kind = kind
            self.count = count
        }
    }

    /// 数を書くか。1種類だけなら書かない
    public var showsCounts: Bool { entries.count > 1 }

    /// 材料が無いときは nil
    init?(ingredients: [Ingredient]) {
        entries = NutrientSource.Kind.allCases.compactMap { kind in
            let count = ingredients.filter { $0.nutrientSource.kind == kind }.count
            return count > 0 ? Entry(kind: kind, count: count) : nil
        }
        guard !entries.isEmpty else { return nil }
    }
}
