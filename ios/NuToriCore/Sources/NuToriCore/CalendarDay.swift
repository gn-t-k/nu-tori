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
        // weekday は日曜が 1、月曜が 2
        let daysSinceMonday = (Self.utcCalendar.component(.weekday, from: startInUTC) + 5) % 7
        return advanced(by: -daysSinceMonday)
    }
}

extension CalendarDay: Strideable {
    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public func distance(to other: CalendarDay) -> Int {
        Self.utcCalendar.dateComponents([.day], from: startInUTC, to: other.startInUTC).day!
    }

    public func advanced(by days: Int) -> CalendarDay {
        let instant = Self.utcCalendar.date(byAdding: .day, value: days, to: startInUTC)!
        return CalendarDay(containing: instant, in: Self.utcCalendar.timeZone)
    }
}

extension CalendarDay {
    private static let utcCalendar = gregorianCalendar(in: .gmt)

    private var startInUTC: Date {
        Self.utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func gregorianCalendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
