/// ヘルスケアに書く栄養の種類。ヘルスケアの型（`HKQuantityTypeIdentifier`）との対応はアプリが持つ。
/// 水分は書かないので持たず、食塩相当量はナトリウムに換算して書く
public enum HealthNutrient: Sendable, Hashable, CaseIterable {
    case energy
    case protein
    case fat
    case carbohydrates
    case fiber
    case sodium
    case cholesterol
    case potassium
    case calcium
    case magnesium
    case phosphorus
    case iron
    case zinc
    case copper
    case manganese
    case iodine
    case selenium
    case chromium
    case molybdenum
    case vitaminA
    case vitaminD
    case vitaminE
    case vitaminK
    case thiamin
    case riboflavin
    case niacin
    case vitaminB6
    case vitaminB12
    case folate
    case pantothenicAcid
    case biotin
    case vitaminC

    /// 書く値の単位
    public enum Unit: Sendable, Hashable {
        case kilocalorie
        case gram
        case milligram
        case microgram
    }

    /// アプリで見せる栄養のうち、この種類に書く値の元
    public var source: Nutrient {
        switch self {
        case .energy: .energyKcal
        case .protein: .proteinG
        case .fat: .fatG
        case .carbohydrates: .carbohydrateG
        case .fiber: .fiberG
        case .sodium: .saltEquivalentG
        case .cholesterol: .cholesterolMg
        case .potassium: .potassiumMg
        case .calcium: .calciumMg
        case .magnesium: .magnesiumMg
        case .phosphorus: .phosphorusMg
        case .iron: .ironMg
        case .zinc: .zincMg
        case .copper: .copperMg
        case .manganese: .manganeseMg
        case .iodine: .iodineUg
        case .selenium: .seleniumUg
        case .chromium: .chromiumUg
        case .molybdenum: .molybdenumUg
        case .vitaminA: .vitaminAUg
        case .vitaminD: .vitaminDUg
        case .vitaminE: .vitaminEMg
        case .vitaminK: .vitaminKUg
        case .thiamin: .vitaminB1Mg
        case .riboflavin: .vitaminB2Mg
        case .niacin: .niacinMg
        case .vitaminB6: .vitaminB6Mg
        case .vitaminB12: .vitaminB12Ug
        case .folate: .folateUg
        case .pantothenicAcid: .pantothenicAcidMg
        case .biotin: .biotinUg
        case .vitaminC: .vitaminCMg
        }
    }

    public var unit: Unit {
        switch self {
        case .energy: .kilocalorie
        case .protein, .fat, .carbohydrates, .fiber: .gram
        case .sodium, .cholesterol, .potassium, .calcium, .magnesium, .phosphorus, .iron, .zinc,
            .copper, .manganese, .vitaminE, .thiamin, .riboflavin, .niacin, .vitaminB6,
            .pantothenicAcid, .vitaminC:
            .milligram
        case .iodine, .selenium, .chromium, .molybdenum, .vitaminA, .vitaminD, .vitaminK,
            .vitaminB12, .folate, .biotin:
            .microgram
        }
    }

    /// 見せる値（`source` の単位）から、書く値にする。食塩相当量 g をナトリウム mg に換算する（Na mg = 食塩相当量 g × 1000 ÷ 2.54）
    func writtenAmount(fromShown shown: Double) -> Double {
        switch self {
        case .sodium: shown * 1000 / 2.54
        case .energy, .protein, .fat, .carbohydrates, .fiber, .cholesterol, .potassium, .calcium,
            .magnesium, .phosphorus, .iron, .zinc, .copper, .manganese, .iodine, .selenium,
            .chromium, .molybdenum, .vitaminA, .vitaminD, .vitaminE, .vitaminK, .thiamin,
            .riboflavin, .niacin, .vitaminB6, .vitaminB12, .folate, .pantothenicAcid, .biotin,
            .vitaminC:
            shown
        }
    }
}
