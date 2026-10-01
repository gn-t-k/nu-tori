/// 栄養の合計の1項目。「不明」の材料が混じるかで3つに分かれる
public enum NutrientAmount: Hashable, Sendable {
    /// すべての材料が「不明」
    case unknown
    /// すべての材料の値が分かる（材料が無いときの 0 も含む）
    case exactly(Double)
    /// 「不明」の材料が混じる。分かる分だけを足した値で、実際はそれより多い（画面では値に「以上」を付ける）
    case atLeast(Double)

    /// 分かる分の値。不明なら nil
    public var value: Double? {
        switch self {
        case .unknown: nil
        case .exactly(let value), .atLeast(let value): value
        }
    }

    /// 値に「以上」を付けるか
    public var isLowerBound: Bool {
        switch self {
        case .atLeast: true
        case .unknown, .exactly: false
        }
    }
}
