import NuToriCore

extension WeightTrend {
    /// 始まりの日から1日ずつ、並べた kg を傾向にする
    static func starting(_ firstDay: CalendarDay, kilograms: [Double]) -> WeightTrend {
        WeightTrend(
            days: kilograms.enumerated().map { offset, kilograms in
                Day(day: firstDay.advanced(by: offset), kilograms: kilograms)
            })
    }
}
