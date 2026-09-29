public struct RingStrip: Sendable {
    /// 使い始めた週から、タイムラインの最後の日がある週まで、古い順
    public let weeks: [Week]

    public init(timeline: Timeline) {
        let daysWithWeightRecord = Set(
            timeline.days.filter { !$0.weightRecords.isEmpty }.map(\.day))
        let firstDay = timeline.dayRange.lowerBound
        let mondays = stride(
            from: firstDay.startOfWeek,
            through: timeline.dayRange.upperBound.startOfWeek,
            by: 7
        )
        weeks = mondays.map { monday in
            Week(
                slots: (0..<7).map { offset in
                    let day = monday.advanced(by: offset)
                    return day < firstDay
                        ? .beforeFirstDay(day)
                        : .ring(day, hasWeightRecord: daysWithWeightRecord.contains(day))
                }
            )
        }
    }

    public struct Week: Hashable, Sendable {
        /// 月曜から日曜まで
        public let slots: [Slot]
    }

    public enum Slot: Hashable, Sendable {
        /// 丸を描かない
        case beforeFirstDay(CalendarDay)
        case ring(CalendarDay, hasWeightRecord: Bool)

        public var day: CalendarDay {
            switch self {
            case .beforeFirstDay(let day), .ring(let day, _): day
            }
        }
    }
}
