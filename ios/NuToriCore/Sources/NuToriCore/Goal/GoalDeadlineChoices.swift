import Foundation

/// 期限のページで選べる日とチップ。電波が無くても期限に答えられるよう、端末が開始の日から出す（ルートの `AGENTS.md` の基準1）。
/// 受け付ける幅（開始の日から両端を含めて 28〜182 日）の正本は `shared/accepted-deadline-days.json`（`AcceptedDeadlineDays` に書き出す）
public struct GoalDeadlineChoices: Sendable, Equatable {
    public let startDay: CalendarDay
    /// 選べる最初の日（開始の日から数えて 28 日め）
    public let earliestDay: CalendarDay
    /// 選べる最後の日（182 日め。26 週めの最後の日）
    public let latestDay: CalendarDay
    /// 1か月後・2か月後・3か月後・6か月後。6か月後が最後の日を越えるときは 26 週後
    public let chips: [Chip]

    public init(startDay: CalendarDay) {
        self.startDay = startDay
        earliestDay = startDay.advanced(by: AcceptedDeadlineDays.minimum - 1)
        let latestDay = startDay.advanced(by: AcceptedDeadlineDays.maximum - 1)
        self.latestDay = latestDay
        chips = [1, 2, 3, 6].map { months in
            let day = Self.day(months: months, after: startDay)
            return day <= latestDay
                ? Chip(label: .months(months), day: day)
                : Chip(label: .weeks(AcceptedDeadlineDays.maximum / 7), day: latestDay)
        }
    }

    /// 期限の初期値（3か月後）
    public var initialDay: CalendarDay {
        // 3か月後は最後の日（182 日め）より前なので、いつも月のチップになる
        guard let chip = chips.first(where: { $0.label == .months(3) }) else {
            preconditionFailure("3か月後のチップが無い")
        }
        return chip.day
    }

    public func contains(_ day: CalendarDay) -> Bool {
        (earliestDay...latestDay).contains(day)
    }

    public struct Chip: Sendable, Equatable {
        public let label: Label
        public let day: CalendarDay
    }

    public enum Label: Sendable, Equatable {
        case months(Int)
        case weeks(Int)
    }

    /// 月の終わりにない日は、その月の最後の日にする（1月31日の1か月後は2月28日）
    private static func day(months: Int, after start: CalendarDay) -> CalendarDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard
            let startDate = calendar.date(
                from: DateComponents(year: start.year, month: start.month, day: start.day)),
            let date = calendar.date(byAdding: .month, value: months, to: startDate)
        else { return start.advanced(by: months * 30) }
        return CalendarDay(containing: date, in: .gmt)
    }
}
