public struct Timeline: Sendable {
    /// タイムラインに並べる日で、日のまとめで送れる日でもある
    public let dayRange: ClosedRange<CalendarDay>

    public init(weightRecords: [WeightRecord], firstDay: CalendarDay, today: CalendarDay) {
        let byDay = Dictionary(grouping: weightRecords.filter { $0.day >= firstDay }, by: \.day)
        let lastDay = ([today] + byDay.keys).max()!
        dayRange = firstDay...max(firstDay, lastDay)
        weightRecordsByDay = byDay.mapValues { $0.sorted { $0.instant < $1.instant } }
    }

    /// 古い日から新しい日へ
    public var days: [Day] {
        dayRange.map { Day(day: $0, weightRecords: weightRecordsByDay[$0] ?? []) }
    }

    public struct Day: Hashable, Sendable {
        public let day: CalendarDay
        /// 実際の時刻の順
        public let weightRecords: [WeightRecord]

        public var representativeWeight: RepresentativeWeight? {
            RepresentativeWeight(sameDayRecords: weightRecords)
        }
    }

    private let weightRecordsByDay: [CalendarDay: [WeightRecord]]
}
