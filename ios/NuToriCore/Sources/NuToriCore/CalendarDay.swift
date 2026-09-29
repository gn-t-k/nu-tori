public import Foundation

public struct CalendarDay: Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(containing instant: Date, in timeZone: TimeZone) {
        let calendar = Self.gregorianCalendar(in: timeZone)
        self.init(
            year: calendar.component(.year, from: instant),
            month: calendar.component(.month, from: instant),
            day: calendar.component(.day, from: instant)
        )
    }

    public var startOfWeek: CalendarDay {
        let calendar = Self.gregorianCalendar(in: .gmt)
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        // weekday は日曜が 1、月曜が 2
        let daysSinceMonday = (calendar.component(.weekday, from: date) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: date)!
        return CalendarDay(containing: monday, in: calendar.timeZone)
    }

    private static func gregorianCalendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
