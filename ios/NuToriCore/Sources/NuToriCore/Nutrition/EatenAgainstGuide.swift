/// その日に食べた量を、1日の目安の1項目（kcal か P・F・C の g）と比べたもの。
/// 日のまとめの丸の中（残りか超過）と、P・F・C の行のバー（右端が目安）に出す
public struct EatenAgainstGuide: Hashable, Sendable {
    public let eaten: NutrientAmount
    public let guide: Int
    public let nutrient: Nutrient

    public init(eaten: NutrientAmount, guide: Int, of nutrient: Nutrient) {
        self.eaten = eaten
        self.guide = guide
        self.nutrient = nutrient
    }

    /// 丸の中に上から「あと / 1,199 / kcal」「超過 / 120 / kcal」と並べる文。
    /// 数は丸めた食べた量から数え、丸の下の「551 / 1,750 kcal」と合わせる
    public var remainder: Remainder {
        guard let rounded else {
            return Remainder(lead: nil, number: "—", unit: nutrient.unit)
        }
        let difference = guide - rounded
        let isOver = difference < 0
        let number = NutritionText.number(.exactly(Double(abs(difference))), of: nutrient)
        // 「不明」の材料が混じる日は、食べた量が多くなりうるので、残りは多くてその値、超過は少なくてその値
        let bound = eaten.isLowerBound ? (isOver ? " 以上" : " 以下") : ""
        return Remainder(
            lead: isOver ? "超過" : "あと", number: number, unit: nutrient.unit + bound)
    }

    /// バーを満たす長さ（右端の目安を 1 とする）。目安を超えたら 1 で止める。食べた量が分からなければ 0
    public var filledFraction: Double {
        guard guide > 0, let value = eaten.value else { return 0 }
        return min(value / Double(guide), 1)
    }

    /// 目安を超えたか。超えた行は数を太字にする（色では分けない）。数に出す丸めた値で比べる
    public var exceedsGuide: Bool {
        guard guide > 0, let rounded else { return false }
        return rounded > guide
    }

    private var rounded: Int? {
        eaten.value.map { Int($0.rounded()) }
    }

    public struct Remainder: Hashable, Sendable {
        /// 「あと」「超過」。食べた量が分からなければ nil
        public let lead: String?
        public let number: String
        public let unit: String

        public init(lead: String?, number: String, unit: String) {
            self.lead = lead
            self.number = number
            self.unit = unit
        }
    }
}
