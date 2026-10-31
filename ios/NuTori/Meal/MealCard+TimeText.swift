import NuToriCore

extension MealCard {
    /// カードの中と、返事の下の指し示す食事の行に出す撮った時刻
    var eatenTimeText: String {
        switch eatenTime {
        case .clock(let clock):
            WeightAmountText.clock(clock)
        case .dayAndClock(let day, let clock):
            "\(TimelineDayText.label(for: day))\(WeightAmountText.clock(clock))"
        }
    }

    /// タイムラインのカードの外に出す送った時刻
    var sentTimeText: String {
        WeightAmountText.clock(sentTime)
    }
}
