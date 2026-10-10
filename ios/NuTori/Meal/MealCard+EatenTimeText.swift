import NuToriCore

extension MealCard {
    /// カードと、返事の下の指し示す食事の行に出す時刻
    var eatenTimeText: String {
        switch eatenTime {
        case .clock(let clock):
            WeightAmountText.clock(clock)
        case .dayAndClock(let day, let clock):
            "\(TimelineDayText.label(for: day))\(WeightAmountText.clock(clock))"
        }
    }
}
