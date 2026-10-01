#if DEBUG
    import Foundation
    import NuToriCore

    extension Meal {
        /// プレビューの見本の、撮った食事。撮った時刻は日本時間で、1分後に送った
        static func sample(
            on day: CalendarDay, at hour: Int, _ minute: Int, photoCount: Int = 1
        ) -> Meal {
            let eatenAt = sampleInstant(on: day, at: hour, minute)
            return Meal(
                id: UUID(),
                eatenAt: eatenAt,
                eatenUtcOffsetSeconds: sampleTimeZone.secondsFromGMT(for: eatenAt),
                sentAt: eatenAt.addingTimeInterval(60),
                sentTimeZone: sampleTimeZone,
                entry: .captured,
                photoIds: (0..<photoCount).map { _ in UUID() }
            )
        }

        /// プレビューの見本の、撮っておいた写真を選んだ食事。`sentOn` の日の 8:00 に選んだ
        static func samplePicked(
            eatenOn day: CalendarDay, at hour: Int, _ minute: Int, sentOn: CalendarDay,
            photoCount: Int
        ) -> Meal {
            let eatenAt = sampleInstant(on: day, at: hour, minute)
            return Meal(
                id: UUID(),
                eatenAt: eatenAt,
                eatenUtcOffsetSeconds: sampleTimeZone.secondsFromGMT(for: eatenAt),
                sentAt: sampleInstant(on: sentOn, at: 8, 0),
                sentTimeZone: sampleTimeZone,
                entry: .picked,
                photoIds: (0..<photoCount).map { _ in UUID() }
            )
        }

        private static let sampleTimeZone = TimeZone(identifier: "Asia/Tokyo")!

        private static func sampleInstant(on day: CalendarDay, at hour: Int, _ minute: Int)
            -> Date
        {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = sampleTimeZone
            return calendar.date(
                from: DateComponents(
                    year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))!
        }
    }
#endif
