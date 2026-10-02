#if DEBUG
    import Foundation
    import NuToriCore

    extension CalendarDay {
        /// プレビューの見本の今日（木曜）
        static let sampleToday = CalendarDay(year: 2026, month: 9, day: 24)
    }

    extension TimeZone {
        /// プレビューの見本のタイムゾーン。見本の記録の時刻もこのタイムゾーン
        static let sampleTokyo = TimeZone(identifier: "Asia/Tokyo")!
    }

    extension Date {
        /// プレビューの見本の今。見本の今日の正午
        static let sampleNow: Date = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .sampleTokyo
            let today = CalendarDay.sampleToday
            return calendar.date(
                from: DateComponents(year: today.year, month: today.month, day: today.day, hour: 12)
            )!
        }()
    }
#endif
