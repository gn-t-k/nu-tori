/// 1日の丸の帯に出す、その日の丸
public struct DayRing: Hashable, Sendable {
    public let hasWeightRecord: Bool
    /// その日の食べた量。丸を塗るかと、日のまとめの値はここから出す
    public let food: DayFood

    public init(hasWeightRecord: Bool, food: DayFood) {
        self.hasWeightRecord = hasWeightRecord
        self.food = food
    }

    /// 食事の無い日の丸
    public init(hasWeightRecord: Bool) {
        self.init(hasWeightRecord: hasWeightRecord, food: .noMeals)
    }

    /// 丸を P・F・C の割合で塗るときの割合。空の輪にするときは nil。
    /// 推定が済んだ食事の kcal があり、P・F・C のどれかが 0 より大きい日だけ塗る
    public var shares: PFCShares? {
        food.figures?.shares
    }

    /// 食事を記録した日として、帯の記録の続き具合（習慣トラッカー）に入れるか。塗った丸の日だけ
    public var hasRecordedFood: Bool {
        shares != nil
    }
}
