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
