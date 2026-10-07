public import Foundation

/// 食事の料理と材料、栄養の合計。食事の画面とタイムラインのカード、日の丸が使う。
/// 親の食事・料理がまだ届いていない料理と材料は入れない（親が届くまで画面に出さない）
public struct MealContents: Hashable, Sendable {
    /// 食事の中の並び順（同じなら ID の順）
    public let dishes: [DishContents]
    /// 食事の栄養の合計。分かる料理（待っていない料理）の分だけを足し、待っている料理があれば値に「以上」が付く
    public let totals: NutrientTotals
    /// 栄養の出どころの1行。分かる料理に材料が無い食事は nil
    public let nutrientSourceLine: NutrientSourceLine?
    /// 「栄養の出典 ›」の行を置くか。分かる料理に、成分表を使った材料が1つでもあるとき
    public let showsNutrientCitation: Bool

    /// カードの名前の場所に置く、料理の名前を並び順に「・」でつないだもの。料理が無ければ nil
    public var name: String? {
        dishes.isEmpty ? nil : dishes.map(\.dish.name).joined(separator: "・")
    }

    /// 量と材料を待っている料理があるか
    public var hasWaitingDishes: Bool { Self.hasWaiting(dishes) }

    /// `dishes` と `ingredients` と `dishEstimationStatuses` は、全部の食事・全部の料理のものを渡してよい（この食事のものだけを取り出す）。
    /// `unsentDishIds` は、送り待ちに料理を足す・名前を直す書き込みがある料理（`DishSyncing.unsentDishIds(in:)`）。
    /// `mealState` は、食事のカードの状態
    public init(
        mealId: UUID,
        dishes: [Dish],
        ingredients: [Ingredient],
        dishEstimationStatuses: [UUID: DishEstimationStatus],
        unsentDishIds: Set<UUID>,
        mealState: MealCardState
    ) {
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
                    ingredientsInAnyOrder: ingredientsByDish[dish.id] ?? [],
                    progress: DishProgress(
                        dish: dish, status: dishEstimationStatuses[dish.id],
                        unsent: unsentDishIds.contains(dish.id), mealState: mealState))
            }
        let combined = NutrientTotals(combining: self.dishes.compactMap(\.knownTotals))
        totals = Self.hasWaiting(self.dishes) ? combined.markingIncomplete() : combined
        // 待っている料理の材料は、推定し直しが届く前のものなので数えない
        let knownIngredients = self.dishes.filter { $0.knownTotals != nil }.flatMap(\.ingredients)
        nutrientSourceLine = NutrientSourceLine(ingredients: knownIngredients)
        showsNutrientCitation = knownIngredients.contains {
            $0.nutrientSource.kind == .foodComposition
        }
    }

    private static func hasWaiting(_ dishes: [DishContents]) -> Bool {
        dishes.contains { $0.progress.isWaiting }
    }
}
