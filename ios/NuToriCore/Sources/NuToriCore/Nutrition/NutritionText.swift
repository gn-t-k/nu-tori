import Foundation

/// 栄養の値と料理・材料の量を、画面に出す文にする。量は数と単位の間を空ける（DESIGN.md）
public enum NutritionText {
    /// 「510 kcal」「78 g 以上」。kcal と g は整数に丸める。すべての材料が「不明」なら「—」
    public static func amount(_ amount: NutrientAmount, of nutrient: Nutrient) -> String {
        guard let value = amount.value else { return "—" }
        let text = "\(wholeNumber(value)) \(nutrient.unit)"
        return amount.isLowerBound ? "\(text) 以上" : text
    }

    /// 単位を別に置くところ（丸の中の kcal）に出す数だけ。「以上」も付けない。不明なら「—」
    public static func number(_ amount: NutrientAmount, of nutrient: Nutrient) -> String {
        amount.value.map(wholeNumber) ?? "—"
    }

    /// 数と別に置く単位（丸の中や食事の合計の kcal）。「不明」の材料が混じる値には「以上」を付ける
    public static func unit(_ amount: NutrientAmount, of nutrient: Nutrient) -> String {
        amount.isLowerBound ? "\(nutrient.unit) 以上" : nutrient.unit
    }

    /// 「110 g」「2個」。小数は1桁まで。英字の単位だけ数との間を空ける（「個」「杯」は続ける）
    public static func quantity(_ quantity: Double, unit: String) -> String {
        let tenths = Int((quantity * 10).rounded())
        let number =
            tenths % 10 == 0 ? "\(tenths / 10)" : "\(tenths / 10).\(abs(tenths % 10))"
        let spaced = unit.first.map { $0.isASCII || $0 == "µ" } ?? false
        return spaced ? "\(number) \(unit)" : "\(number)\(unit)"
    }

    /// 「栄養の出どころ: 栄養成分表示 1・成分表 4・推定 1」。1種類だけなら数を書かない。「AI」とは書かない
    public static func sourceLine(_ line: NutrientSourceLine) -> String {
        let entries = line.entries.map { entry in
            line.showsCounts ? "\(entry.kind.name) \(entry.count)" : entry.kind.name
        }
        return "栄養の出どころ: \(entries.joined(separator: "・"))"
    }

    /// 3桁ごとに「,」で区切った整数
    private static func wholeNumber(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        var digits = String(abs(rounded))
        var groups: [String] = []
        while digits.count > 3 {
            groups.insert(String(digits.suffix(3)), at: 0)
            digits.removeLast(3)
        }
        groups.insert(digits, at: 0)
        return (rounded < 0 ? "-" : "") + groups.joined(separator: ",")
    }
}

extension NutrientSource.Kind {
    fileprivate var name: String {
        switch self {
        case .nutritionLabel: "栄養成分表示"
        case .foodComposition: "成分表"
        case .estimated: "推定"
        }
    }
}
