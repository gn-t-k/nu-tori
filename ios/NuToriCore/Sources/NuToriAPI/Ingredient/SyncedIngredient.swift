public import Foundation

/// 材料。サーバーが推定の完了で作る。親の料理は ID で持つ
public struct SyncedIngredient: Sendable, Equatable {
    public let id: UUID
    public let dishId: UUID
    public let name: String
    public let quantity: Double
    public let unit: String
    /// 1単位あたりの可食部の g
    public let edibleGramsPerUnit: Double
    /// 料理の中の並び順。同じ値は ID の順で並べる
    public let positionInDish: Int
    public let nutrientSource: NutrientSource
    /// 栄養の項目の名前（`shared/nutrients.json` のキー）ごとの、基準あたりの値。不明の項目は持たない。
    /// 知らない名前も、読み飛ばさずここでは持つ（読み飛ばすのは NuToriCore）
    public let nutrients: [String: Double]

    public init(
        id: UUID,
        dishId: UUID,
        name: String,
        quantity: Double,
        unit: String,
        edibleGramsPerUnit: Double,
        positionInDish: Int,
        nutrientSource: NutrientSource,
        nutrients: [String: Double]
    ) {
        self.id = id
        self.dishId = dishId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.edibleGramsPerUnit = edibleGramsPerUnit
        self.positionInDish = positionInDish
        self.nutrientSource = nutrientSource
        self.nutrients = nutrients
    }

    /// 栄養の値の出どころ
    public enum NutrientSource: Sendable, Equatable {
        /// 栄養成分表示。値は表示の単位あたりで、その可食部の g を持つ
        case nutritionLabel(basisGrams: Double)
        /// 成分表。引いた食品番号を持つ（5 桁の文字列）
        case foodComposition(foodNumber: String)
        case estimated
    }
}
