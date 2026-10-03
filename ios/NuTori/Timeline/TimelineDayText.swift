import Foundation
import NuToriCore

nonisolated enum TimelineDayText {
    static func label(for day: CalendarDay) -> String {
        let weekday = weekdaySymbol(for: day)
        if weekday.isEmpty {
            return "\(day.month)月\(day.day)日"
        }
        return "\(day.month)月\(day.day)日（\(weekday)）"
    }

    static func weekdaySymbol(for day: CalendarDay) -> String {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard
            let date = utcCalendar.date(
                from: DateComponents(year: day.year, month: day.month, day: day.day))
        else { return "" }
        let weekday = utcCalendar.component(.weekday, from: date)
        return symbols[weekday - 1]
    }

    static func startedOn(for day: CalendarDay) -> String {
        String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
    }
}
