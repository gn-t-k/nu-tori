/// サーバーが受け付けなかった食事（サーバーに値が無い）を、カードを外した位置に一時的に出す1行
public struct RejectedMealLine: Hashable, Sendable {
    public let meal: Meal

    public init(meal: Meal) {
        self.meal = meal
    }

    public var text: String {
        "\(WeightAmountText.clock(meal.eatenClockTime)) の食事は、記録できませんでした。"
    }
}
