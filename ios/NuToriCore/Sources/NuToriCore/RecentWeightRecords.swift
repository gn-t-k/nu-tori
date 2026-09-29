public struct RecentWeightRecords: Sendable {
    /// 新しい順に1日1つ
    public let sinceFirstDay: [RepresentativeWeight]
    /// 新しい順に1日1つ
    public let beforeFirstDay: [RepresentativeWeight]

    public init(weightRecords: [WeightRecord], firstDay: CalendarDay, today: CalendarDay) {
        let recentDayCount = 28
        let windowStart = today.advanced(by: 1 - recentDayCount)
        let representativeWeights = Dictionary(
            grouping: weightRecords.filter { $0.day >= windowStart },
            by: \.day
        )
        .values
        .compactMap { RepresentativeWeight(sameDayRecords: $0) }
        .sorted { $0.day > $1.day }
        sinceFirstDay = representativeWeights.filter { $0.day >= firstDay }
        beforeFirstDay = representativeWeights.filter { $0.day < firstDay }
    }
}
