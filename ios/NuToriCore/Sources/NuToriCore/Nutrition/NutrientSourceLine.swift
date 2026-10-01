/// 栄養の出どころの1行の値。材料の数を、栄養成分表示・成分表・推定の順に並べ、0 のものは入れない。
/// 文言（「栄養の出どころ: 成分表 4・推定 1」）は画面が組む
public struct NutrientSourceLine: Hashable, Sendable {
    public let entries: [Entry]

    public struct Entry: Hashable, Sendable {
        public let kind: NutrientSource.Kind
        public let count: Int

        public init(kind: NutrientSource.Kind, count: Int) {
            self.kind = kind
            self.count = count
        }
    }

    /// 数を書くか。1種類だけなら書かない
    public var showsCounts: Bool { entries.count > 1 }

    /// 材料が無いときは nil
    init?(ingredients: [Ingredient]) {
        entries = NutrientSource.Kind.allCases.compactMap { kind in
            let count = ingredients.filter { $0.nutrientSource.kind == kind }.count
            return count > 0 ? Entry(kind: kind, count: count) : nil
        }
        guard !entries.isEmpty else { return nil }
    }
}
