/// 丸を一周した長さのうち、たんぱく質・脂質・炭水化物が占める割合（合計は 1）。
/// その日の kcal を P×4 : F×9 : C×4 の比で分けたもの（kcal の数え方は ADR-0016）
public struct PFCShares: Hashable, Sendable {
    public let protein: Double
    public let fat: Double
    public let carbohydrate: Double

    public init(protein: Double, fat: Double, carbohydrate: Double) {
        self.protein = protein
        self.fat = fat
        self.carbohydrate = carbohydrate
    }

    /// P・F・C の分かる分から出す。「不明」の分は 0 として数える。すべて 0 以下なら nil
    init?(totals: NutrientTotals) {
        let protein = max(totals[.proteinG].value ?? 0, 0) * 4
        let fat = max(totals[.fatG].value ?? 0, 0) * 9
        let carbohydrate = max(totals[.carbohydrateG].value ?? 0, 0) * 4
        let sum = protein + fat + carbohydrate
        guard sum > 0 else { return nil }
        self.init(protein: protein / sum, fat: fat / sum, carbohydrate: carbohydrate / sum)
    }
}
