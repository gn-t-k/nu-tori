import Foundation

/// 料理と、その材料（並び順）。料理の行に出す栄養の合計を持つ
public struct DishContents: Hashable, Sendable {
    public let dish: Dish
    public let ingredients: [Ingredient]
    /// 今の材料の合計。待っている料理では、推定し直しが届く前の材料のもの（画面の合計には足さない。`knownTotals`）
    public let totals: NutrientTotals
    /// 料理ごとの待ちの見え方
    public let progress: DishProgress

    public init(dish: Dish, ingredients: [Ingredient], progress: DishProgress = .settled) {
        self.dish = dish
        self.ingredients = ingredients
        self.progress = progress
        totals = NutrientTotals(ingredients: ingredients)
    }

    /// 料理の材料を、並び順（同じなら ID の順）に並べて持つ。画面とヘルスケアが、同じ順で足した同じ合計を出すため
    public init(
        dish: Dish, ingredientsInAnyOrder ingredients: [Ingredient],
        progress: DishProgress = .settled
    ) {
        self.init(
            dish: dish,
            ingredients: ingredients.sorted {
                ($0.positionInDish, $0.id.uuidString) < ($1.positionInDish, $1.id.uuidString)
            },
            progress: progress
        )
    }

    /// 食事の画面の料理の行に出すもの
    public var row: DishRow { DishRow(contents: self) }

    /// 料理の画面に、材料と栄養のまとまり（主な栄養・ミネラル・ビタミンと注記）を出すか。待っている料理と通らなかった料理は出さない
    public var showsIngredientsAndNutrients: Bool { progress == .settled }

    /// 食事の合計に足す分。待っている料理は nil。材料の無い料理（通らなかった料理）は、すべての栄養が分かる 0
    var knownTotals: NutrientTotals? {
        switch progress {
        case .notSent, .estimating, .deferredToNextDay: nil
        case .unestimable: .knownZero
        case .settled: ingredients.isEmpty ? .knownZero : totals
        }
    }
}
