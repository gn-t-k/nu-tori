/// 1日の丸の帯に出す、その日の丸
public struct DayRing: Hashable, Sendable {
    public let hasWeightRecord: Bool
    /// その日の食べた量。丸を塗るかと、日のまとめの値はここから出す
    public let food: DayFood
    /// その日の食べた量を比べる1日の目安。nil の日（目標を立てる前の日など）は比べず、P・F・C の割合で一周する
    public let dailyGuide: DailyGuide?

    public init(hasWeightRecord: Bool, food: DayFood, dailyGuide: DailyGuide?) {
        self.hasWeightRecord = hasWeightRecord
        self.food = food
        self.dailyGuide = dailyGuide
    }

    /// 食事の無い日の丸
    public init(hasWeightRecord: Bool) {
        self.init(hasWeightRecord: hasWeightRecord, food: .noMeals, dailyGuide: nil)
    }

    /// 丸を P・F・C の割合で塗るときの割合。空の輪にするときは nil。
    /// 推定が済んだ食事の kcal があり、P・F・C のどれかが 0 より大きい日だけ塗る
    public var shares: PFCShares? {
        food.figures?.shares
    }

    /// 一周を 1 とした、P・F・C を塗る長さ。空の輪にするときは nil。
    /// 1日の目安と比べる日は、一周を目安にして食べた kcal の分だけ進み（目安を超えたら一周で止める）、
    /// 比べない日は P・F・C の割合で一周する（DESIGN.md の「1日の丸」）
    public var arcs: Arcs? {
        guard let shares else { return nil }
        let filled = eatenFractionOfGuide.map { min($0, 1) } ?? 1
        return Arcs(
            protein: shares.protein * filled, fat: shares.fat * filled,
            carbohydrate: shares.carbohydrate * filled)
    }

    /// 食べた kcal が1日の目安を超えたか（輪の起点に印を付ける）。比べない日は false
    public var exceedsDailyGuide: Bool {
        (eatenFractionOfGuide ?? 0) > 1
    }

    /// 食べた kcal ÷ 1日の目安。比べない日と、kcal の出ない日は nil
    private var eatenFractionOfGuide: Double? {
        guard let dailyGuide, dailyGuide.energyKilocalories > 0,
            let eaten = food.figures?.totals[.energyKcal].value
        else { return nil }
        return eaten / Double(dailyGuide.energyKilocalories)
    }

    /// 一周を 1 とした、P・F・C それぞれの長さ。合計は 1 以下
    public struct Arcs: Hashable, Sendable {
        public let protein: Double
        public let fat: Double
        public let carbohydrate: Double

        public init(protein: Double, fat: Double, carbohydrate: Double) {
            self.protein = protein
            self.fat = fat
            self.carbohydrate = carbohydrate
        }
    }

    /// 食事を記録した日として、帯の記録の続き具合（習慣トラッカー）に入れるか。塗った丸の日だけ
    public var hasRecordedFood: Bool {
        shares != nil
    }
}
