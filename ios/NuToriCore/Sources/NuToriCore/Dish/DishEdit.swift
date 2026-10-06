import Foundation
public import NuToriAPI

/// 料理を直した結果。キャッシュに当てる料理と材料と、送る料理を直す書き込みの中身を持つ。
/// 料理を直す書き込みは、名前と量を両方運ぶ（量の無い料理は名前だけ）
public struct DishEdit: Sendable, Equatable {
    /// 直したあとの料理
    public let dish: Dish
    /// 量を変えた材料（料理の量を直したときの比例）。名前だけを直したときは空
    public let ingredients: [Ingredient]
    public let correction: DishCorrection
    /// 名前を直したか（量を直したのでなく）
    public let renames: Bool

    /// 送り待ちに入れる書き込み
    public var write: DishWrite {
        renames ? .rename(correction) : .update(correction)
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
            ingredients: proportioned,
            correction: correction(of: corrected, ingredients: proportioned),
            renames: false)
    }

    /// 料理の名前を直す。前後の空白を除いた名前にし、量と材料は変えない。
    /// 書き込みには今の量と今の材料の量を載せる（量の無い料理は名前だけ）。
    /// 前後の空白を除いて受け付ける範囲の外（空）の名前と、今と同じ名前は直さず nil（空なら、画面は前の名前に戻す）
    public static func renaming(_ dish: Dish, ingredients: [Ingredient], to typedName: String)
        -> DishEdit?
    {
        let name = typedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AcceptedRange.dishNameTrimmedLength.bounds.contains(Double(name.count)),
            name != dish.name
        else { return nil }
        let renamed = dish.with(name: name, quantity: dish.quantity)
        return DishEdit(
            dish: renamed,
            ingredients: [],
            correction: correction(
                of: renamed, ingredients: ingredientsInOrder(of: dish, among: ingredients)),
            renames: true)
    }

    /// 量の無い料理は、量と比例の材料を省く
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
        DishContents(
            dish: dish, ingredientsInAnyOrder: ingredients.filter { $0.dishId == dish.id }
        ).ingredients
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
