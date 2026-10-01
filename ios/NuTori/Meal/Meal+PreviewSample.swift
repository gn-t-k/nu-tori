#if DEBUG
    import Foundation
    import NuToriCore

    extension Meal {
        /// プレビューの見本の、撮った食事。撮った時刻は日本時間で、1分後に送った
        static func sample(on day: CalendarDay, at hour: Int, _ minute: Int) -> Meal {
            let timeZone = TimeZone(identifier: "Asia/Tokyo")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let eatenAt = calendar.date(
                from: DateComponents(
                    year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))!
            return Meal(
                id: UUID(),
                eatenAt: eatenAt,
                eatenUtcOffsetSeconds: timeZone.secondsFromGMT(for: eatenAt),
                sentAt: eatenAt.addingTimeInterval(60),
                sentTimeZone: timeZone,
                entry: .captured,
                photoIds: [UUID()]
            )
        }
    }
#endif
