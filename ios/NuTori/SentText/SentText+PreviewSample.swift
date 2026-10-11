#if DEBUG
    import Foundation
    import NuToriCore

    extension SentText {
        /// プレビューの見本の、日本時間で送った文章
        static func sample(_ body: String, on day: CalendarDay, at hour: Int, _ minute: Int)
            -> SentText
        {
            let timeZone = TimeZone(identifier: "Asia/Tokyo")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return SentText(
                id: UUID(), body: body,
                sentAt: calendar.date(
                    from: DateComponents(
                        year: day.year, month: day.month, day: day.day, hour: hour, minute: minute)
                )!,
                timeZone: timeZone)
        }
    }
#endif
