import Foundation
import NuToriCore
import SwiftData

/// 材料。料理とは別の種類で、料理より先に届くこともあるので、親の料理の ID を値で持つ
@Model
nonisolated final class CachedIngredient {
    @Attribute(.unique) var ingredientId: UUID
    var dishId: UUID
    var name: String
    var quantity: Double
    /// `estimated`・`corrected`
    var quantitySource: String
    var unit: String
    var edibleGramsPerUnit: Double
    var positionInDish: Int
    /// `nutrition_label`・`food_composition`・`estimated`
    var sourceType: String
    /// `nutrition_label` のときだけ持つ。表示の単位あたりの可食部の g
    var labelBasisGrams: Double?
    /// `food_composition` のときだけ持つ。食品番号（5 桁の文字列）
    var foodNumber: String?
    /// 栄養の項目の名前（サーバーの名前）と値。同じ位置どうしが組。「不明」の項目は持たない
    var nutrientNames: [String]
    var nutrientValues: [Double]

    init(_ ingredient: Ingredient) {
        ingredientId = ingredient.id
        dishId = ingredient.dishId
        name = ingredient.name
        quantity = ingredient.quantity
        quantitySource = ingredient.quantitySource.stored
        unit = ingredient.unit
        edibleGramsPerUnit = ingredient.edibleGramsPerUnit
        positionInDish = ingredient.positionInDish
        let stored = Self.stored(ingredient.nutrientSource)
        sourceType = stored.type
        labelBasisGrams = stored.labelBasisGrams
        foodNumber = stored.foodNumber
        let nutrients = Self.stored(ingredient.nutrients)
        nutrientNames = nutrients.names
        nutrientValues = nutrients.values
    }

    /// 同じ ID が届き直したときは、その値にそろえる
    func apply(_ ingredient: Ingredient) {
        dishId = ingredient.dishId
        name = ingredient.name
        quantity = ingredient.quantity
        quantitySource = ingredient.quantitySource.stored
        unit = ingredient.unit
        edibleGramsPerUnit = ingredient.edibleGramsPerUnit
        positionInDish = ingredient.positionInDish
        let stored = Self.stored(ingredient.nutrientSource)
        sourceType = stored.type
        labelBasisGrams = stored.labelBasisGrams
        foodNumber = stored.foodNumber
        let nutrients = Self.stored(ingredient.nutrients)
        nutrientNames = nutrients.names
        nutrientValues = nutrients.values
    }

    /// 栄養か量の出どころを読めないとき（形が合わない行）は nil
    func ingredient() -> Ingredient? {
        guard let source = nutrientSource(),
            let storedQuantitySource = QuantitySource(stored: quantitySource)
        else { return nil }
        var nutrients: [Nutrient: Double] = [:]
        for (name, value) in zip(nutrientNames, nutrientValues) {
            if let nutrient = Nutrient(rawValue: name) {
                nutrients[nutrient] = value
            }
        }
        return Ingredient(
            id: ingredientId,
            dishId: dishId,
            name: name,
            quantity: quantity,
            quantitySource: storedQuantitySource,
            unit: unit,
            edibleGramsPerUnit: edibleGramsPerUnit,
            positionInDish: positionInDish,
            nutrientSource: source,
            nutrients: nutrients
        )
    }

    private func nutrientSource() -> NutrientSource? {
        switch sourceType {
        case "nutrition_label": labelBasisGrams.map { .nutritionLabel(basisGrams: $0) }
        case "food_composition": foodNumber.map { .foodComposition(foodNumber: $0) }
        case "estimated": .estimated
        // swiftlint:disable:next no_default_in_switch - 置き場の文字列は、知らない値を読めないとみなす
        default: nil
        }
    }

    private static func stored(_ source: NutrientSource) -> (
        type: String, labelBasisGrams: Double?, foodNumber: String?
    ) {
        switch source {
        case .nutritionLabel(let basisGrams): ("nutrition_label", basisGrams, nil)
        case .foodComposition(let foodNumber): ("food_composition", nil, foodNumber)
        case .estimated: ("estimated", nil, nil)
        }
    }

    /// 名前の順に並べて持つ（同じ値は同じ並びで保存するため）
    private static func stored(_ nutrients: [Nutrient: Double]) -> (
        names: [String], values: [Double]
    ) {
        let sorted = nutrients.sorted { $0.key.rawValue < $1.key.rawValue }
        return (sorted.map { $0.key.rawValue }, sorted.map { $0.value })
    }
}
