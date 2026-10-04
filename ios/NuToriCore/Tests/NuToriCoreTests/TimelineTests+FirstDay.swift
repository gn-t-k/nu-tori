import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("始まりの日")
    struct FirstDay {
        static let today = CalendarDay(year: 2026, month: 9, day: 25)

        @Suite("使い始めた日があり、それより前の体重記録もあるとき")
        struct StartedDayWithEarlierRecord {
            let firstDay: CalendarDay

            init() throws {
                firstDay = Timeline.firstDay(
                    startedDay: CalendarDay(year: 2026, month: 9, day: 23),
                    weightRecords: [
                        try .imported(73.0, at: "2026-09-20T06:48:00+09:00", in: "Asia/Tokyo")
                    ],
                    today: FirstDay.today)
            }

            @Test("使い始めた日にすること")
            func usesStartedDay() {
                #expect(firstDay == CalendarDay(year: 2026, month: 9, day: 23))
            }
        }

        @Suite("使い始めた日があり、体重記録が無いとき")
        struct StartedDayWithoutRecords {
            let firstDay: CalendarDay

            init() {
                firstDay = Timeline.firstDay(
                    startedDay: CalendarDay(year: 2026, month: 9, day: 23),
                    weightRecords: [],
                    today: FirstDay.today)
            }

            @Test("使い始めた日にすること")
            func usesStartedDay() {
                #expect(firstDay == CalendarDay(year: 2026, month: 9, day: 23))
            }
        }

        @Suite("使い始めた日が無く、体重記録があるとき")
        struct RecordsWithoutStartedDay {
            let firstDay: CalendarDay

            init() throws {
                firstDay = Timeline.firstDay(
                    startedDay: nil,
                    weightRecords: [
                        try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo"),
                        try .imported(73.0, at: "2026-09-21T06:48:00+09:00", in: "Asia/Tokyo"),
                    ],
                    today: FirstDay.today)
            }

            @Test("いちばん古い体重記録の日にすること")
            func usesOldestRecordDay() {
                #expect(firstDay == CalendarDay(year: 2026, month: 9, day: 21))
            }
        }

        @Suite("使い始めた日も体重記録も無いとき")
        struct NeitherStartedDayNorRecords {
            let firstDay: CalendarDay

            init() {
                firstDay = Timeline.firstDay(
                    startedDay: nil, weightRecords: [], today: FirstDay.today)
            }

            @Test("今日にすること")
            func usesToday() {
                #expect(firstDay == FirstDay.today)
            }
        }
    }
}
