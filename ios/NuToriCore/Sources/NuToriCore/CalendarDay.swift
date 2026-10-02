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

    /// 時刻に、その時刻の UTC との時差を足した UTC の日付の日
    public init(containing instant: Date, utcOffsetSeconds: Int) {
        let localInstant = instant.addingTimeInterval(TimeInterval(utcOffsetSeconds))
        let calendar = Self.utcCalendar
        self.init(
            year: calendar.component(.year, from: localInstant),
            month: calendar.component(.month, from: localInstant),
            day: calendar.component(.day, from: localInstant)
        )
    }

    public init(containing instant: Date, in timeZone: TimeZone) {
        self.init(containing: instant, utcOffsetSeconds: timeZone.secondsFromGMT(for: instant))
    }

    /// `YYYY-MM-DD`（サーバーとの受け渡しの形）から読む。形が違うときと、暦に無い日（2月31日など）は nil
    public init?(yearMonthDay text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }
        // Calendar は暦に無い日を次の月へ繰り越すので、日付に戻して同じ年月日かで確かめる。
        // == は Strideable の既定（日数の差が 0 か）で、繰り越した日と等しくなるので使わない
        guard
            let instant = Self.utcCalendar.date(
                from: DateComponents(year: year, month: month, day: day))
        else {
            return nil
        }
        let carried = CalendarDay(containing: instant, utcOffsetSeconds: 0)
        guard (carried.year, carried.month, carried.day) == (year, month, day) else {
            return nil
        }
        self.init(year: year, month: month, day: day)
    }

    /// `YYYY-MM-DD`（サーバーとの受け渡しの形）
    public var yearMonthDay: String {
        String(format: "%04d-%02d-%02d", year, month, day)
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
        return CalendarDay(containing: instant, utcOffsetSeconds: 0)
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
