public struct RingStrip: Sendable {
    /// 使い始めた週から、タイムラインの最後の日がある週まで、古い順
    public let weeks: [Week]

    public init(timeline: Timeline) {
        let ringsByDay = Dictionary(uniqueKeysWithValues: timeline.days.map { ($0.day, $0.ring) })
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
                        : .ring(day, ringsByDay[day] ?? DayRing(hasWeightRecord: false))
                }
            )
        }
    }

    public struct Week: Hashable, Sendable {
        /// 月曜から日曜まで
        public let slots: [Slot]

        public init(slots: [Slot]) {
            self.slots = slots
        }
    }

    public enum Slot: Hashable, Sendable {
        /// 丸を描かない
        case beforeFirstDay(CalendarDay)
        case ring(CalendarDay, DayRing)

        public var day: CalendarDay {
            switch self {
            case .beforeFirstDay(let day), .ring(let day, _): day
            }
        }
    }
}
