#if DEBUG
    import Foundation
    import NuToriCore

    extension Notice {
        /// プレビューの見本の体重の知らせ。日本時間の 8:00 に出し、答えていれば答えた時刻（時と分）を持つ
        static func sampleMissedWeightRecord(
            on day: CalendarDay, respondedAt hourAndMinute: (hour: Int, minute: Int)?
        ) -> Notice {
            let timeZone = TimeZone(identifier: "Asia/Tokyo")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let issuedAt = calendar.date(
                from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 8))!
            return Notice(
                id: Notice.id(kind: .missedWeightRecord, targetDay: day),
                kind: .missedWeightRecord,
                issuedAt: issuedAt,
                timeZone: timeZone,
                targetDay: day,
                response: hourAndMinute.map { time in
                    Notice.Response(
                        respondedAt: calendar.date(
                            from: DateComponents(
                                year: day.year, month: day.month, day: day.day, hour: time.hour,
                                minute: time.minute))!,
                        timeZone: timeZone)
                }
            )
        }
    }
#endif
