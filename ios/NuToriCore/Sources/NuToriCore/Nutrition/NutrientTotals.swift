/// 料理・食事・日の栄養の合計。値の分かる材料の分だけを足し、「不明」の材料が混じる栄養は「以上」にする。
/// すべての材料が「不明」の栄養だけが「不明」で、kcal は材料の kcal の和（P・F・C から出し直さない。ADR-0016）
public struct NutrientTotals: Hashable, Sendable {
    /// 材料の栄養の値（`Ingredient.amount(of:)`）を足し上げる
    public init(ingredients: [Ingredient]) {
        entries = Dictionary(
            uniqueKeysWithValues: Nutrient.allCases.map { nutrient in
                var entry = Entry()
                for ingredient in ingredients {
                    if let amount = ingredient.amount(of: nutrient) {
                        entry.sum += amount
                        entry.hasKnown = true
                    } else {
                        entry.hasUnknown = true
                    }
                }
                return (nutrient, entry)
            })
    }

    /// 料理の合計から食事の合計、食事の合計から日の合計を出す。材料から直に出した合計と同じになる
    public init(combining totals: [NutrientTotals]) {
        entries = Dictionary(
            uniqueKeysWithValues: Nutrient.allCases.map { nutrient in
                var entry = Entry()
                for total in totals {
                    let other = total.entry(of: nutrient)
                    entry.sum += other.sum
                    entry.hasKnown = entry.hasKnown || other.hasKnown
                    entry.hasUnknown = entry.hasUnknown || other.hasUnknown
                }
                return (nutrient, entry)
            })
    }

    public subscript(nutrient: Nutrient) -> NutrientAmount {
        let entry = entry(of: nutrient)
        switch (entry.hasKnown, entry.hasUnknown) {
        case (false, true): return .unknown
        case (_, true): return .atLeast(entry.sum)
        case (_, false): return .exactly(entry.sum)
        }
    }

    private struct Entry: Hashable, Sendable {
        var sum = 0.0
        var hasKnown = false
        var hasUnknown = false
    }

    private let entries: [Nutrient: Entry]

    private func entry(of nutrient: Nutrient) -> Entry {
        entries[nutrient] ?? Entry()
    }
}
