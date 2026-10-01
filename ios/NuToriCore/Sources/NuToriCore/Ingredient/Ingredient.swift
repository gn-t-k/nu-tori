public import Foundation

/// 材料。サーバーが推定の完了で作り、同期で届く。親の料理は ID で持つ（料理より先に届くことがある）
public struct Ingredient: Hashable, Sendable {
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
    /// 基準（`NutrientSource.basisGrams`）あたりの値。「不明」の項目はキーを持たない
    public let nutrients: [Nutrient: Double]

    public init(
        id: UUID,
        dishId: UUID,
        name: String,
        quantity: Double,
        unit: String,
        edibleGramsPerUnit: Double,
        positionInDish: Int,
        nutrientSource: NutrientSource,
        nutrients: [Nutrient: Double]
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

    /// 材料の量に含まれる栄養の値。材料の値 × 量 × 1単位あたりの可食部の g ÷ 基準の g。「不明」なら nil
    public func amount(of nutrient: Nutrient) -> Double? {
        nutrients[nutrient].map { $0 * quantity * edibleGramsPerUnit / nutrientSource.basisGrams }
    }
}

/// 栄養の値の出どころ
public enum NutrientSource: Hashable, Sendable {
    /// 栄養成分表示。値は表示の単位あたりで、その可食部の g を持つ
    case nutritionLabel(basisGrams: Double)
    /// 成分表。引いた食品番号を持つ（5 桁の文字列）
    case foodComposition(foodNumber: String)
    case estimated

    /// 値の基準の g。成分表と推定は可食部 100 g
    public var basisGrams: Double {
        switch self {
        case .nutritionLabel(let basisGrams): basisGrams
        case .foodComposition, .estimated: 100
        }
    }

    public var kind: Kind {
        switch self {
        case .nutritionLabel: .nutritionLabel
        case .foodComposition: .foodComposition
        case .estimated: .estimated
        }
    }

    /// 出どころの種類。栄養の出どころの1行は、この順に並べる
    public enum Kind: Hashable, Sendable, CaseIterable {
        case nutritionLabel
        case foodComposition
        case estimated
    }
}
