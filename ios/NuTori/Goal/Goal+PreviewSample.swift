#if DEBUG
    import Foundation
    import NuToriCore

    extension Goal {
        /// プレビューの見本の減量の目標。日本時間の `startedDay` の 8:02 に決めた、12月24日までに 72.4 kg から 70.1 kg へ減らす標準の目標
        static func sampleLosing(startedOn startedDay: CalendarDay) -> Goal {
            Goal(
                id: UUID(uuidString: "6F1C2A40-0000-4000-8000-000000000001")!,
                startedDay: startedDay,
                startingWeightTrendKilograms: 72.4,
                targetWeightKilograms: 70.1,
                decidedAt: sampleDecidedAt(on: startedDay),
                timeZone: sampleTimeZone,
                direction: .lose(
                    WeightChange(
                        deadlineDay: CalendarDay(year: 2026, month: 12, day: 24),
                        pacePlan: .standard)),
                achievement: nil,
                deadlineConfirmation: nil,
                closure: nil
            )
        }

        /// プレビューの見本の維持の目標。日本時間の `startedDay` の 8:02 に決めた、65.0 kg を保つ目標
        static func sampleMaintaining(startedOn startedDay: CalendarDay) -> Goal {
            Goal(
                id: UUID(uuidString: "6F1C2A40-0000-4000-8000-000000000002")!,
                startedDay: startedDay,
                startingWeightTrendKilograms: 65.0,
                targetWeightKilograms: 65.0,
                decidedAt: sampleDecidedAt(on: startedDay),
                timeZone: sampleTimeZone,
                direction: .maintain,
                achievement: nil,
                deadlineConfirmation: nil,
                closure: nil
            )
        }

        private static let sampleTimeZone = TimeZone(identifier: "Asia/Tokyo")!

        private static func sampleDecidedAt(on day: CalendarDay) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = sampleTimeZone
            return calendar.date(
                from: DateComponents(
                    year: day.year, month: day.month, day: day.day, hour: 8, minute: 2))!
        }
    }
#endif
