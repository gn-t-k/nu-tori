public import Foundation

/// サーバーが受け付けなかった食事・料理・材料の書き込みを、一時的に出す1行。
/// 置き方は `docs/agents/sync.md` の「受け付けなかった書き込みに添える今の値」: サーバーに値があればその記録の位置に「直せなかった」行、
/// 削除の印か無ければ記録を外した位置に「記録できなかった」行。推定し直しで材料が入れ替わっていたときは、今の値が削除の印でも「直せなかった」行
public struct RejectedMealLine: Hashable, Sendable {
    /// 端末で見せていた食事。時刻と、タイムラインに出すときの位置（送った時刻）はここから出す
    public let meal: Meal
    public let subject: Subject

    /// 受け付けなかった食事（サーバーに値が無い）を、カードを外した位置に出す1行
    public init(meal: Meal) {
        self.init(meal: meal, subject: .meal)
    }

    public init(meal: Meal, subject: Subject) {
        self.meal = meal
        self.subject = subject
    }

    /// 行にする記録と、直そうとした値
    public enum Subject: Hashable, Sendable {
        /// 食事を記録できなかった（作る書き込みでサーバーに無い、直そうとした食事が消えていた）
        case meal
        /// 撮った時刻を直せなかった。直そうとした時刻
        case eatenAt(attempted: Date)
        /// 足した料理を記録できなかった（食事が無かった）
        case addedDish(DishPlace)
        /// 料理の名前を直せなかった。直そうとした名前
        case dishName(DishPlace, attempted: String)
        /// 料理の量を直せなかった（推定し直しで材料が入れ替わっていたときも）。直そうとした量と、料理の単位
        case dishQuantity(DishPlace, attempted: Double, unit: String)
        /// 直そうとした料理が消えていた。名前は端末で見せていた名前
        case goneDish(DishPlace)
        /// 材料の量を直せなかった（サーバーに値がある）。直そうとした量
        case ingredientQuantity(IngredientPlace, attempted: Double)
        /// 推定し直しで置き換わった前の材料の量を直そうとした。直そうとした量
        case replacedIngredient(IngredientPlace, attempted: Double)
        /// 直そうとした材料が、料理ごと消えていた
        case goneIngredient(IngredientPlace)
    }

    /// 端末で見せていた料理
    public struct DishPlace: Hashable, Sendable {
        public let id: UUID
        public let name: String
        public let positionInMeal: Int

        public init(id: UUID, name: String, positionInMeal: Int) {
            self.id = id
            self.name = name
            self.positionInMeal = positionInMeal
        }
    }

    /// 端末で見せていた材料と、その料理
    public struct IngredientPlace: Hashable, Sendable {
        public let id: UUID
        public let name: String
        public let unit: String
        public let positionInDish: Int
        public let dish: DishPlace

        public init(id: UUID, name: String, unit: String, positionInDish: Int, dish: DishPlace) {
            self.id = id
            self.name = name
            self.unit = unit
            self.positionInDish = positionInDish
            self.dish = dish
        }
    }

    /// 1行が指す記録の ID。同じ記録の古い1行は、新しい1行に置き換える
    public var recordId: UUID {
        switch subject {
        case .meal, .eatenAt: meal.id
        case .addedDish(let dish), .dishName(let dish, _), .dishQuantity(let dish, _, _),
            .goneDish(let dish):
            dish.id
        case .ingredientQuantity(let ingredient, _), .replacedIngredient(let ingredient, _),
            .goneIngredient(let ingredient):
            ingredient.id
        }
    }

    public var text: String {
        let mealTime = WeightAmountText.clock(meal.eatenClockTime)
        switch subject {
        case .meal:
            return "\(mealTime) の食事は、記録できませんでした。"
        case .eatenAt(let attempted):
            let clock = ClockTime(
                containing: attempted, utcOffsetSeconds: meal.eatenUtcOffsetSeconds)
            return "\(WeightAmountText.clock(clock)) に直せませんでした。"
        case .addedDish(let dish):
            return "\(mealTime) の食事に足した\(dish.name)は、記録できませんでした。"
        case .dishName(_, let attempted):
            return "\(attempted) に直せませんでした。"
        case .dishQuantity(_, let attempted, let unit):
            return "\(Self.quantity(attempted, unit: unit))に直せませんでした。"
        case .goneDish(let dish):
            return "\(mealTime) の食事の \(dish.name) は、記録できませんでした。"
        case .ingredientQuantity(let ingredient, let attempted):
            return "\(Self.quantity(attempted, unit: ingredient.unit))に直せませんでした。"
        case .replacedIngredient(let ingredient, let attempted):
            return
                "\(ingredient.name) \(Self.quantity(attempted, unit: ingredient.unit))に直せませんでした。"
        case .goneIngredient(let ingredient):
            return
                "\(mealTime) の食事の \(ingredient.dish.name) の \(ingredient.name) は、記録できませんでした。"
        }
    }

    /// 今のキャッシュでの置き場。`card` は、その食事の今のカード（食事が消えていれば nil）。
    /// 記録を外した位置に出す行は、親が残っていればその親の中の位置に、親も消えていればもう1つ上の親の中の位置に出す
    public func placement(in card: MealCard?) -> Placement {
        guard let card else { return .timeline }
        let dishes = card.contents.dishes
        func dishPlacement(_ dish: DishPlace) -> Placement {
            dishes.contains { $0.dish.id == dish.id }
                ? .belowDish(dish.id) : .inDishList(positionInMeal: dish.positionInMeal)
        }
        func ingredientListPlacement(_ ingredient: IngredientPlace) -> Placement {
            guard let contents = dishes.first(where: { $0.dish.id == ingredient.dish.id }) else {
                return .inDishList(positionInMeal: ingredient.dish.positionInMeal)
            }
            // 料理の画面に材料の一覧が無ければ（材料が無い、待っている・通らなかった料理）、料理の行の下
            guard contents.showsIngredientsAndNutrients, !contents.ingredients.isEmpty else {
                return .belowDish(ingredient.dish.id)
            }
            return .inIngredientList(
                dishId: ingredient.dish.id, positionInDish: ingredient.positionInDish)
        }
        switch subject {
        case .meal:
            return .timeline
        case .eatenAt:
            return .belowEatenAt
        case .addedDish(let dish), .goneDish(let dish):
            return .inDishList(positionInMeal: dish.positionInMeal)
        case .dishName(let dish, _), .dishQuantity(let dish, _, _):
            return dishPlacement(dish)
        case .ingredientQuantity(let ingredient, _):
            let contents = dishes.first { $0.dish.id == ingredient.dish.id }
            if contents?.ingredients.contains(where: { $0.id == ingredient.id }) == true,
                contents?.showsIngredientsAndNutrients == true
            {
                return .belowIngredient(ingredient.id)
            }
            return ingredientListPlacement(ingredient)
        case .replacedIngredient(let ingredient, _), .goneIngredient(let ingredient):
            return ingredientListPlacement(ingredient)
        }
    }

    public enum Placement: Hashable, Sendable {
        /// タイムラインの、その食事のカードを置いていた位置（送った時刻の順）
        case timeline
        /// 食事の画面の時刻の下
        case belowEatenAt
        /// 食事の画面の、その料理の行の下（料理の画面では名前と量の下）
        case belowDish(UUID)
        /// 食事の画面の料理の一覧の、その並び順の位置（料理の行を外した位置）
        case inDishList(positionInMeal: Int)
        /// 料理の画面の、その材料の行の下
        case belowIngredient(UUID)
        /// 料理の画面の材料の一覧の、その並び順の位置（材料の行を外した位置）
        case inIngredientList(dishId: UUID, positionInDish: Int)
    }

    /// 受け付けなかった1行のうち、その食事の1行（ほかの食事と体重の1行を除く）
    static func lines(of meal: Meal, among rejectedLines: [RejectedLine]) -> [RejectedMealLine] {
        rejectedLines.compactMap(\.mealLine).filter { $0.meal.id == meal.id }
    }

    /// 「1.5杯」「150 g 」。英字の単位は「に」との間も空ける（体重の「71.9 kg に直せませんでした。」にそろえる）
    private static func quantity(_ value: Double, unit: String) -> String {
        let text = NutritionText.quantity(value, unit: unit)
        let endsWithLatinUnit = unit.last.map { $0.isASCII || $0 == "µ" } ?? false
        return endsWithLatinUnit ? "\(text) " : text
    }
}
