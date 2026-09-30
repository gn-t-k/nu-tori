public struct RepresentativeWeight: Hashable, Sendable {
    public let record: WeightRecord
    /// 同じ日の、代表のほかの体重記録の数
    public let otherRecordCount: Int

    public var day: CalendarDay {
        record.day
    }

    init?(sameDayRecords records: [WeightRecord]) {
        guard let first = records.min(by: { $0.instant < $1.instant }) else {
            return nil
        }
        record = first
        otherRecordCount = records.count - 1
    }
}
