#if DEBUG
    import Foundation
    import NuToriCore

    extension WeightRecord {
        /// プレビューの見本の記録。時刻は日本時間で、版は 1
        static func sample(
            _ kilograms: Double, on day: CalendarDay, at hour: Int, _ minute: Int,
            from inputSource: InputSource
        ) -> WeightRecord {
            let timeZone = TimeZone(identifier: "Asia/Tokyo")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let components = DateComponents(
                year: day.year, month: day.month, day: day.day, hour: hour, minute: minute)
            return WeightRecord(
                id: UUID(),
                kilograms: kilograms,
                instant: calendar.date(from: components)!,
                timeZone: timeZone,
                inputSource: inputSource,
                version: 1
            )
        }

        /// プレビューの見本の、9月14日（月）に立てた減量の目標（`Goal.sampleWeeklyReviewed`）の1週目の月〜日の体重記録（水・金・土）。
        /// 週の振り返り（`WeeklyReview.sampleReviewed`）で見直した週
        static let sampleWeeklyReviewedWeek: [WeightRecord] = [2, 4, 5].map {
            .sample(
                72.2 - Double($0) * 0.1,
                on: Goal.sampleWeeklyReviewed.startedDay.advanced(by: $0), at: 7, 0,
                from: .manual)
        }
    }

    extension WeightRecord.InputSource {
        /// ヘルスケアから取り込んだ、ほかのアプリの記録
        static let sampleScaleApp = WeightRecord.InputSource.imported(
            WeightRecord.ImportedSource(
                appName: "体重計アプリ",
                bundleId: "com.example.scale",
                healthKitSampleId: UUID(),
                bodyFat: nil
            )
        )
    }
#endif
