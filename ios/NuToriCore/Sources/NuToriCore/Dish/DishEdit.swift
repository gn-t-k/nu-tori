import Foundation
public import NuToriAPI

/// 料理を直した結果。キャッシュに当てる料理と材料と、送る料理を直す書き込みの中身を持つ。
/// 料理を直す書き込みは、量を直したときは名前と量と比例の材料を、名前を直したときは名前だけを運ぶ
public struct DishEdit: Sendable, Equatable {
    /// 直したあとの料理
    public let dish: Dish
    public let correction: DishCorrection
    public let change: Change

    /// 名前を直したか、量を直したか
    public enum Change: Sendable, Equatable {
        case renamed
        /// 比例で量を変えた材料を持つ
        case quantityCorrected(proportioned: [Ingredient])
    }

    /// 量を変えた材料（料理の量を直したときの比例）。名前を直したときは空
    public var ingredients: [Ingredient] {
        switch change {
        case .renamed: []
        case .quantityCorrected(let proportioned): proportioned
        }
    }

    /// 送り待ちに入れる書き込み
    public var write: DishWrite {
        switch change {
        case .renamed: .rename(correction)
        case .quantityCorrected: .update(correction)
        }
    }

    /// 料理の量を直す。その料理の今の材料の量を、同じ割合（直した量 ÷ 前の量）で変える（比例）。
    /// 料理の量の出どころは「直した」になり、比例で変えた材料の量の出どころはそのまま。
    /// 量の無い料理、受け付ける範囲の外の量、今と同じ量は直さず nil。`ingredients` はほかの料理の材料を含んでよい
    public static func correctingQuantity(
        of dish: Dish, ingredients: [Ingredient], to value: Double
    ) -> DishEdit? {
        guard let quantity = dish.quantity, AcceptedRange.dishQuantity.bounds.contains(value),
            value != quantity.value
        else { return nil }
        let ratio = value / quantity.value
        let proportioned = ingredientsInOrder(of: dish, among: ingredients).map {
            $0.withQuantity($0.quantity * ratio, source: $0.quantitySource)
        }
        let corrected = dish.with(
            name: dish.name,
            quantity: Dish.Quantity(value: value, unit: quantity.unit, source: .corrected))
        return DishEdit(
            dish: corrected,
            correction: correction(of: corrected, ingredients: proportioned),
            change: .quantityCorrected(proportioned: proportioned))
    }

    /// 料理の名前を直す。前後の空白を除いた名前にし、量と材料は変えない。
    /// 書き込みには量と比例の材料を載せない（載せると、推定し直しで材料が入れ替わったあとに届いた直しが受け付けられなくなる）。
    /// 前後の空白を除いて受け付ける範囲の外（空）の名前と、今と同じ名前は直さず nil（空なら、画面は前の名前に戻す）
    public static func renaming(_ dish: Dish, to typedName: String) -> DishEdit? {
        guard let name = Dish.acceptedName(typed: typedName), name != dish.name else { return nil }
        let renamed = dish.with(name: name, quantity: dish.quantity)
        return DishEdit(
            dish: renamed,
            correction: DishCorrection(id: dish.id, name: name, quantity: nil),
            change: .renamed)
    }

    private static func correction(of dish: Dish, ingredients: [Ingredient]) -> DishCorrection {
        DishCorrection(
            id: dish.id,
            name: dish.name,
            quantity: dish.quantity.map { quantity in
                DishCorrection.Quantity(
                    value: quantity.value,
                    proportionedIngredients: ingredients.map {
                        DishCorrection.ProportionedIngredient(
                            ingredientId: $0.id, quantity: $0.quantity)
                    })
            })
    }

    /// その料理の材料を、並び順（同じなら ID の順）に並べる。同じ材料からは同じ書き込みを作るため
    private static func ingredientsInOrder(of dish: Dish, among ingredients: [Ingredient])
        -> [Ingredient]
    {
        ingredients.filter { $0.dishId == dish.id }.sortedInDishOrder()
    }
}

extension Dish {
    func with(name: String, quantity: Quantity?) -> Dish {
        Dish(
            id: id, mealId: mealId, name: name, quantity: quantity,
            positionInMeal: positionInMeal, version: version)
    }
}

extension Ingredient {
    func withQuantity(_ quantity: Double, source: QuantitySource) -> Ingredient {
        Ingredient(
            id: id, dishId: dishId, name: name, quantity: quantity, quantitySource: source,
            unit: unit, edibleGramsPerUnit: edibleGramsPerUnit, positionInDish: positionInDish,
            nutrientSource: nutrientSource, nutrients: nutrients)
    }
}
