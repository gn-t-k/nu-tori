import Foundation

/// 料理の画面の栄養の内訳（主な栄養・ミネラル・ビタミン）。値は料理の今の材料の値を足したもの（`NutrientTotals`）。
/// 一部の材料だけ分からない栄養は「以上」、どの材料でも分からない栄養は「不明」にする。
/// 待っている料理と通らなかった料理には出さない（`DishContents.showsIngredientsAndNutrients`）
public struct DishNutrientBreakdown: Hashable, Sendable {
    public let groups: [Group]

    /// 画面の下に1回だけ書く、2つの意味
    public static let note =
        "「以上」は、一部の材料の値が分からず、分かる分だけを足した値です。「不明」は、どの材料も値が分からない栄養です。"

    public init(_ contents: DishContents) {
        groups = Self.layout.map { title, nutrients in
            Group(
                title: title,
                rows: nutrients.map { nutrient in
                    Row(nutrient: nutrient, amount: contents.totals[nutrient])
                })
        }
    }

    public struct Group: Hashable, Sendable {
        public let title: String
        public let rows: [Row]
    }

    public struct Row: Hashable, Sendable {
        public let nutrient: Nutrient
        public let amount: NutrientAmount

        public var name: String { nutrient.breakdownName }

        /// 「6.0 g」「0.4 mg 以上」「不明」
        public var text: String {
            guard let value = amount.value else { return "不明" }
            let text = "\(Self.number(value, unit: nutrient.unit)) \(nutrient.unit)"
            return amount.isLowerBound ? "\(text) 以上" : text
        }

        /// 「不明」の値は secondaryLabel で書く
        public var isUnknown: Bool { amount == .unknown }

        /// kcal は整数、g は小数1桁。mg と µg は、10 以上を整数、1 以上を小数1桁、1 未満を小数2桁まで（末尾の 0 を除く）。0 は 0
        private static func number(_ value: Double, unit: String) -> String {
            let posix = Locale(identifier: "en_US_POSIX")
            switch unit {
            case "kcal":
                return String(format: "%.0f", locale: posix, value)
            case "g":
                return String(format: "%.1f", locale: posix, value)
            default:
                if value == 0 { return "0" }
                if value >= 10 { return String(format: "%.0f", locale: posix, value) }
                if value >= 1 { return String(format: "%.1f", locale: posix, value) }
                var text = String(format: "%.2f", locale: posix, value)
                while text.hasSuffix("0") { text.removeLast() }
                return text.hasSuffix(".") ? String(text.dropLast()) : text
            }
        }
    }

    /// #188 の「栄養の項目」の表の「内訳の画面」が「出す」15項目。まとまりと並びは `07-components/meal` の「栄養の内訳」
    private static let layout: [(String, [Nutrient])] = [
        (
            "主な栄養",
            [.energyKcal, .proteinG, .fatG, .carbohydrateG, .fiberG, .saltEquivalentG]
        ),
        ("ミネラル", [.calciumMg, .ironMg, .potassiumMg, .magnesiumMg]),
        ("ビタミン", [.vitaminAUg, .vitaminB1Mg, .vitaminB2Mg, .vitaminCMg, .vitaminDUg]),
    ]
}

extension Nutrient {
    /// 内訳の画面に出す名前
    fileprivate var breakdownName: String {
        switch self {
        case .energyKcal: "エネルギー"
        case .proteinG: "たんぱく質"
        case .fatG: "脂質"
        case .carbohydrateG: "炭水化物"
        case .fiberG: "食物繊維"
        case .saltEquivalentG: "食塩相当量"
        case .calciumMg: "カルシウム"
        case .ironMg: "鉄"
        case .potassiumMg: "カリウム"
        case .magnesiumMg: "マグネシウム"
        case .vitaminAUg: "ビタミンA"
        case .vitaminB1Mg: "ビタミンB1"
        case .vitaminB2Mg: "ビタミンB2"
        case .vitaminCMg: "ビタミンC"
        case .vitaminDUg: "ビタミンD"
        case .biotinUg, .cholesterolMg, .chromiumUg, .copperMg, .folateUg, .iodineUg,
            .manganeseMg, .molybdenumUg, .niacinMg, .pantothenicAcidMg, .phosphorusMg,
            .seleniumUg, .vitaminB12Ug, .vitaminB6Mg, .vitaminEMg, .vitaminKUg, .waterG, .zincMg:
            rawValue
        }
    }
}
