#if DEBUG
    import NuToriCore

    extension WeightTrend {
        /// プレビューの見本の傾向。体重記録の最初の日から最後の日まで、1日ずつ決まった量で減る
        static func sample(
            from first: CalendarDay, through last: CalendarDay, startingAt kilograms: Double,
            perDay change: Double
        ) -> WeightTrend {
            WeightTrend(
                days: (0...first.distance(to: last)).map { offset in
                    WeightTrend.Day(
                        day: first.advanced(by: offset),
                        kilograms: kilograms + change * Double(offset))
                })
        }

        /// プレビューの見本の、`Goal.sampleWeeklyReviewed` の開始の日から10日、1日 0.05 kg ずつ減る傾向
        static let sampleWeeklyReviewed = sample(
            from: Goal.sampleWeeklyReviewed.startedDay,
            through: Goal.sampleWeeklyReviewed.startedDay.advanced(by: 9), startingAt: 72.4,
            perDay: -0.05)
    }
#endif
